#
# Copyright 2023, Audian, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

defmodule Numerus.Classifier do
  @moduledoc """
    This module classifies the supplied did into the following types:
    - E.164
    - 1NPAN   (NADP DIDs only)
    - NPAN    (NADP DIDs only)
    - USINTL  (+ to 011)
    """

  require Logger

  alias Numerus.Formatter, as: Formatter

  # -- module attributes -- #

  # define the regexes for each number type
  @nadp     ~r/\A(?:(?:\+1|1))?(?<area_code>[2-9][0-9]{2})(?<exch>[2-9][0-9]{2})(?<number>[0-9]{4})$\z/
  @intl     ~r/\A^011[2-9][0-9][0-9]{8,13}$\z/
  @intl_n   ~r/\A^(?:011|\+)[2-9][0-9]{5,16}$\z/
  @scode    ~r/\A^[2-9][\d]{4,5}\z/
  @natf     ~r/\A(?:(?:\+1|1))?(?:800|888|877|866|855|844|833)[2-9][0-9]{2}[0-9]{4}\z/
  @naprem   ~r/\A(?:(?:\+1|1))?(?:900)[2-9][0-9]{2}[0-9]{4}\z/

  # define regexes for format types
  @e164     ~r/\A^\+[1-9][0-9][0-9]{8,13}$\z/
  @npan     ~r/\A^[2-9][0-9]{2}[2-9][0-9]{6}$\z/
  @one_npan ~r/\A^1[2-9][0-9]{2}[2-9][0-9]{6}$\z/

  @n11      ~r/\A^[2-9]11$\z/

  # parser regex
  # this regex splits the full did into country code + number
  @parser   ~r/(\+|011)(?<countrycode>9[976]\d|8[987530]\d|6[987]\d|5[90]\d|42\d|3[875]\d|2[98654321]\d|9[8543210]|8[6421]|6[6543210]|5[87654321]|4[987654310]|3[9643210]|2[70]|7|1)(?<number>\d{1,14})$/i

  # nadp n11 classification
  @n11_dids %{
    "211" => %{"desc" => "Community Services", "code" => "service"},
    "311" => %{"desc" => "Municipal Government Services", "code" => "service"},
    "411" => %{"desc" => "Directory Information", "code" => "directory_info"},
    "511" => %{"desc" => "Traffic Information", "code" => "traffic_info"},
    "611" => %{"desc" => "Telco Customer Service & Repair", "code" => "support"},
    "711" => %{"desc" => "TDD and Relay", "code" => "tdd"},
    "811" => %{"desc" => "Public Utility Location", "code" => "utility"},
    "911" => %{"desc" => "Emergency Services", "code" => "emergency"},
    "933" => %{"desc" => "Emergency Address Verification", "code" => "address_check"}
  }

  # -- public functions  -- #

  @doc """
  Classify the provided did. This function parses the did and returns a map with the
  formatting and region for the did.

  The North American Dial Plan (NADP) covers multiple countries in North America.
  """
  @spec classify(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def classify(did) when is_bitstring(did) do
    classification = %{
      "region"    => region(did),
      "format"    => format(did),
      "tollstate" => tollstate(did)
    }

    {:ok, classification}
  end
  def classify(_), do: {:error, :invalid_number}

  # -- did classification functions -- #

  @doc "Return true if the did is an N11 did."
  @spec n11?(did :: bitstring()) :: boolean()
  def n11?(did) when is_bitstring(did), do: String.match?(did, @n11)
  def n11?(_), do: false

  @doc "Return true if the number is formatted E164."
  @spec e164?(did :: bitstring()) :: boolean()
  def e164?(did) when is_bitstring(did), do: String.match?(did, @e164)
  def e164?(_), do: false

  @doc "Return true if the number is part of NADP"
  @spec nadp?(did :: bitstring()) :: boolean()
  def nadp?(did) when is_bitstring(did), do: String.match?(did, @nadp)
  def nadp?(_), do: false

  @doc "Return true if the number is formatted E164 and is part of NADP"
  @spec use164?(did :: bitstring()) :: boolean()
  def use164?(did) when is_bitstring(did), do: nadp?(did) and e164?(did)
  def use164?(_), do: false
  def nadpe164?(did) when is_bitstring(did), do: use164?(did)
  def nadpe164?(_), do: false

  @doc "Return true if the did is formatted npan"
  @spec npan?(did :: bitstring()) :: boolean()
  def npan?(did) when is_bitstring(did), do: String.match?(did, @npan)
  def npan?(_), do: false

  @doc "Return true if the did is formatted 1npan."
  @spec one_npan?(did :: bitstring()) :: boolean()
  def one_npan?(did) when is_bitstring(did), do: String.match?(did, @one_npan)
  def one_npan?(_), do: false

  @doc "Return true if the number is a toll free number"
  @spec tollfree?(did :: bitstring()) :: boolean()
  def tollfree?(did) when is_bitstring(did), do: nadp?(did) && String.match?(did, @natf)
  def tollfree?(_), do: false

  @doc "Return true if the number is a shortcode"
  @spec shortcode?(did :: bitstring()) :: boolean()
  def shortcode?(did) when is_bitstring(did), do: String.match?(did, @scode)
  def shortcode?(_), do: false

  @doc "Return true if the number is not part of the NADP or if the number is not from US or Canada"
  @spec intl?(did :: bitstring()) :: boolean()
  def intl?(did) when is_bitstring(did), do: String.match?(did, @intl) or usintl?(did)
  def intl?(_), do: false

  @doc "Return true if the number is formatted as US international (i.e 011XXXXX etc)"
  @spec usintl?(did :: bitstring()) :: boolean()
  def usintl?(did) when is_bitstring(did), do: String.match?(did, @intl_n)
  def usintl?(_), do: false

  @doc "Return true if the number matches a premium did (i.e very high ppm)"
  @spec premium?(did :: bitstring()) :: boolean()
  def premium?(did) when is_bitstring(did), do: String.match?(did, @naprem)
  def premium?(_), do: false

  @doc "extract the number and country code from the did for n11 dids, always return 1 for the country code"
  @spec extract(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def extract(did) when is_bitstring(did) do
    case n11?(did) do
      true  -> {:ok, %{"countrycode" => "1", "number" => did}}
      false ->
        # this is not an emergency did, so lets extract
        case String.match?(did, ~r/(\+1?)?[\d]+/) do
          true  ->
            case Regex.named_captures(@parser, Numerus.normalize(did)) do
              nil -> {:error, :invalid_number_format}
              res -> {:ok, res}
            end

          false -> {:error, :invalid_number_format}
        end
    end
  end
  def extract(_), do: {:error, :invalid_number_format}

  @doc "Split the did."
  @spec split(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def split(did) when is_bitstring(did) do
    case Regex.named_captures(@nadp, did) do
      nil -> {:error, :invalid_number_format}
      res -> {:ok, res}
    end
  end
  def split(_), do: {:error, :invalid_number_format}

  @doc "Normalize the did to the supplied format. If not format is supplied E164 is used"
  @spec normalize(did :: bitstring(), format :: atom() | nil) :: bitstring() | :error
  def normalize(did, format) when is_bitstring(did) do
    case format(did) do
      "shortcode" -> did
      "n11"       -> did
      _           ->
        case format do
          :e164     -> Formatter.to_e164(did)
          :npan     -> Formatter.to_npan(did)
          :one_npan -> Formatter.to_1npan(did)
          :us_intl  -> Formatter.to_usintl(did)
          _         -> :error
        end
    end
  end
  def normalize(_, _), do: :error
  def normalize(did) when is_bitstring(did), do: normalize(did, :e164)
  def normalize(_), do: :error

  @doc "Return metadata for the supplied number"
  @spec metadata(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def metadata(did) when is_bitstring(did) do
    # dispatch on the detected format; each helper returns {:ok, map} | {:error, term}
    case format(did) do
      "unknown"   -> {:ok, basic_metadata(did, %{})}
      "shortcode" -> {:ok, basic_metadata(did, us_meta())}
      "n11"       -> {:ok, basic_metadata(did, us_meta())}
      "us_intl"   -> country_metadata(did)
      "e164"      -> e164_metadata(did)
      n when n in ["npan", "one_npan"] ->
        # normalize to e164 for the lookup, but echo the caller's did back
        case metadata(Numerus.normalize(did)) do
          {:ok, result} -> {:ok, %{result | "did" => did}}
          error         -> error
        end
      _           -> {:error, :invalid_number_format}
    end
  end
  def metadata(_), do: {:error, :invalid_number_format}

  # -- private functions -- #

  # -- metadata helpers -- #

  # standard result map that uses the raw did for the normalized/formatted
  # values (for formats already in their canonical form: unknown/shortcode/n11)
  @spec basic_metadata(did :: bitstring(), meta :: map()) :: map()
  defp basic_metadata(did, meta) do
    %{
      "did"         => did,
      "normalized"  => did,
      "formatted"   => did,
      "tollstate"   => tollstate(did),
      "region"      => region(did),
      "meta"        => meta
    }
  end

  # standard result map that normalizes and formats the did
  @spec full_metadata(did :: bitstring(), meta :: map()) :: map()
  defp full_metadata(did, meta) do
    %{
      "did"         => did,
      "normalized"  => normalize(did),
      "formatted"   => Formatter.format(did),
      "tollstate"   => tollstate(did),
      "region"      => region(did),
      "meta"        => meta
    }
  end

  # the US country meta block used for shortcodes, n11 and tollfree dids
  @spec us_meta() :: map()
  defp us_meta do
    %{
      "country" => %{"name" => "UNITED STATES", "iso" => "US"},
      "state"   => %{}
    }
  end

  # look up a country by dial code, returning {name, iso} (or {nil, nil})
  @spec country_name_iso(countrycode :: bitstring()) ::
          {bitstring() | nil, bitstring() | nil}
  defp country_name_iso(countrycode) do
    case Numerus.Country.metadata(countrycode) do
      {:ok, res}  -> {res["name"], res["iso"]}
      {:error, _} -> {nil, nil}
    end
  end

  # metadata for an international did: extract the country code and look it up
  @spec country_metadata(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  defp country_metadata(did) do
    case extract(did) do
      {:error, _} -> {:error, :invalid_number_format}
      {:ok, meta} ->
        {name, iso} = country_name_iso(meta["countrycode"])
        country = %{"country" => %{"name" => name, "iso" => iso}, "state" => %{}}
        {:ok, full_metadata(did, country)}
    end
  end

  # metadata for an e164 did: tollfree (US), international, or a NADP number
  @spec e164_metadata(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  defp e164_metadata(did) do
    cond do
      tollfree?(did)  -> {:ok, full_metadata(did, us_meta())}
      intl?(did)      -> country_metadata(did)
      nadp?(did)      -> nadp_metadata(did)
      true            -> {:error, :invalid_number_format}
    end
  end

  # metadata for a NADP e164 did (US/CA carry state info, caribbean does not)
  @spec nadp_metadata(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  defp nadp_metadata(did) do
    case Regex.named_captures(@nadp, did) do
      nil -> {:error, :invalid_number_format}
      res ->
        case Numerus.Nadp.metadata(res["area_code"]) do
          {:error, _} -> {:ok, full_metadata(did, %{})}
          {:ok, area} -> {:ok, full_metadata(did, nadp_meta(area))}
        end
    end
  end

  # build the country/state meta for a NADP area-code lookup result
  @spec nadp_meta(area :: map()) :: map()
  defp nadp_meta(area) do
    country = %{"name" => area["country_name"], "iso" => area["country_iso"]}

    state =
      case Enum.member?(["US", "CA"], area["country_iso"]) do
        true  -> %{"name" => area["state_name"], "iso" => area["state_iso"]}
        false -> %{}
      end

    %{"country" => country, "state" => state}
  end

  # return the region for the did
  @spec region(did :: bitstring()) :: bitstring()
  defp region(did) when is_bitstring(did) do
    cond do
      n11?(did)        -> "nadp"
      nadp?(did)       -> "nadp"
      shortcode?(did)  -> "nadp"
      usintl?(did)     -> "international"
      intl?(did)       -> "international"
      true                -> "unknown"
    end
  end

  # return the formatting of the did
  @spec format(did :: bitstring()) :: bitstring()
  def format(did) when is_bitstring(did) do
    cond do
      n11?(did)        -> "n11"
      e164?(did)       -> "e164"
      npan?(did)       -> "npan"
      one_npan?(did)      -> "one_npan"
      shortcode?(did)  -> "shortcode"
      usintl?(did)     -> "us_intl"
      true                -> "unknown"
    end
  end
  def format(_), do: "unknown"

  # return the tollstate for the supplied did
  @spec tollstate(did :: bitstring()) :: bitstring()
  defp tollstate(did) when is_bitstring(did) do
    cond do
      tollfree?(did)   -> "tollfree"
      shortcode?(did)  -> "shortcode"
      n11?(did)        -> service_did_info(did)
      premium?(did)    -> "premium"
      nadp?(did)       -> "standard"
      usintl?(did)     -> "international"
      intl?(did)       -> "international"
      true                -> "unknown"
    end
  end

  # return the list of service dids
  @spec service_dids() :: list()
  defp service_dids() do
    @n11_dids
    |> Enum.map(fn {did, _} -> did end)
  end

  # return information about the service did
  # should return the actual code
  @spec service_did_info(did :: bitstring()) :: bitstring()
  defp service_did_info(did) when is_bitstring(did) do
    case Enum.member?(service_dids(), did) do
      false -> "unknown"
      true  ->
        # this is a service did so lets extract
        case @n11_dids[did] do
          nil -> "unknown"
          res -> res["code"]
        end
    end
  end
end
