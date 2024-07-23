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
    @spec is_n11?(did :: bitstring()) :: boolean()
    def is_n11?(did) when is_bitstring(did), do: String.match?(did, @n11)
    def is_n11?(_), do: false

    @doc "Return trye if the number is formatted E164"
    @spec is_e164?(did :: bitstring()) :: boolean()
    def is_e164?(did) when is_bitstring(did), do: String.match?(did, @e164)
    def is_e164?(_), do: false

    @doc "Return true if the number is part of NADP"
    @spec is_nadp?(did :: bitstring()) :: boolean()
    def is_nadp?(did) when is_bitstring(did), do: String.match?(did, @nadp)
    def is_nadp?(_), do: false

    @doc "Return true if the number is formatted E164 and is part of NADP"
    @spec is_use164?(did :: bitstring()) :: boolean()
    def is_use164?(did) when is_bitstring(did), do: is_nadp?(did) and is_e164?(did)
    def is_use164?(_), do: false
    def is_nadpe164?(did) when is_bitstring(did), do: is_use164?(did)
    def is_nadpe164?(_), do: false

    @doc "Return true if the did is formatted npan"
    @spec is_npan?(did :: bitstring()) :: boolean()
    def is_npan?(did) when is_bitstring(did), do: String.match?(did, @npan)
    def is_npan?(_), do: false

    @doc "Return true of the did is formatted 1npan"
    @spec is_1npan?(did :: bitstring()) :: boolean()
    def is_1npan?(did) when is_bitstring(did), do: String.match?(did, @one_npan)
    def is_1npan?(_), do: false

    @doc "Return true if the number is a toll free number"
    @spec is_tollfree?(did :: bitstring()) :: boolean()
    def is_tollfree?(did) when is_bitstring(did), do: is_nadp?(did) && String.match?(did, @natf)
    def is_tollfree?(_), do: false

    @doc "Return true if the number is a shortcode"
    @spec is_shortcode?(did :: bitstring()) :: boolean()
    def is_shortcode?(did) when is_bitstring(did), do: String.match?(did, @scode)
    def is_shortcode?(_), do: false

    @doc "Return true if the number is not part of the NADP or if the number is not from US or Canada"
    @spec is_intl?(did :: bitstring()) :: boolean()
    def is_intl?(did) when is_bitstring(did), do: String.match?(did, @intl) or is_usintl?(did)
    def is_intl?(_), do: false

    @doc "Return true if the number is formatted as US international (i.e 011XXXXX etc)"
    @spec is_usintl?(did :: bitstring()) :: boolean()
    def is_usintl?(did) when is_bitstring(did), do: String.match?(did, @intl_n)
    def is_usintl?(_), do: false

    @doc "Return true if the number matches a premium did (i.e very high ppm)"
    @spec is_premium?(did :: bitstring()) :: boolean
    def is_premium?(did) when is_bitstring(did), do: String.match?(did, @naprem)
    def is_premium?(_), do: false

    @doc "extract the number and country code from the did for n11 dids, always return 1 for the country code"
    @spec extract(did :: bitstring()) :: {:ok, map()} | {:error, term()}
    def extract(did) when is_bitstring(did) do
      case is_n11?(did) do
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
      # lets determine the format for this did
      case format(did) do
        "unknown" ->
          # this pattern does not match other known patterns. return a map
          # with the did but blank vals for other options
          result = %{
            "did"         => did,
            "normalized"  => did,
            "formatted"   => did,
            "tollstate"   => tollstate(did),
            "region"      => region(did),
            "meta"        => %{}
          }

          {:ok, result}

        "shortcode" ->
          # this is a shortcode, we only support shortcodes in the us
          # and return a country code of 1
          result = %{
            "did"         => did,
            "normalized"  => did,
            "formatted"   => did,
            "tollstate"   => tollstate(did),
            "region"      => region(did),
            "meta"        => %{
              "country" => %{"name" => "UNITED STATES", "iso" => "US"},
              "state"   => %{}
            }
          }

          {:ok, result}

        "n11" ->
          # N11 dids can be emergency or multiple services, ensure
          # service_did_info(did) is called for the tollstate
          result = %{
            "did"         => did,
            "normalized"  => did,
            "formatted"   => did,
            "tollstate"   => tollstate(did),
            "region"      => region(did),
            "meta"        => %{
              "country" => %{"name" => "UNITED STATES", "iso" => "US"},
              "state"   => %{}
            }
          }

          {:ok, result}

        "us_intl" ->
          # lets extract the country code and return the metadata
          case extract(did) do
            {:error, _} -> {:error, :invalid_number_format}
            {:ok, meta} ->
              {name, iso} =
                case Numerus.Country.metadata(meta["countrycode"]) do
                  {:ok, res}  -> {res["name"], res["iso"]}
                  {:error, _} -> {nil, nil}
                end

              result = %{
                "did"           => did,
                "normalized"    => normalize(did),
                "formatted"     => Formatter.format(did),
                "tollstate"     => tollstate(did),
                "region"        => region(did),
                "meta"          => %{
                  "country" => %{"name" => name, "iso" => iso},
                  "state"   => %{}
                }
              }

              {:ok, result}
          end

        "e164"  ->
          # e164 can be tollfree, us, canada (which are considered local) and
          # caribbean countries
          case is_tollfree?(did) do
            true  ->
              # these toll free numbers are us only for our purposes
              # though they can be from any nadp country
              result = %{
                "did"         => did,
                "normalized"  => normalize(did),
                "formatted"   => Formatter.format(did),
                "tollstate"   => tollstate(did),
                "region"      => region(did),
                "meta"        => %{
                  "country" => %{"name" => "UNITED STATES", "iso" => "US"},
                  "state"   => %{}
                }
              }

              {:ok, result}
            false ->
              # these can be international or nadp
              case is_intl?(did) do
                true  ->
                  # international did, parse the country code
                  case extract(did) do
                    {:error, _} -> {:error, :invalid_number_format}
                    {:ok, meta} ->
                      {name, iso} = case Numerus.Country.metadata(meta["countrycode"]) do
                        {:error, _} -> {nil, nil}
                        {:ok, res}  -> {res["name"], res["iso"]}
                      end

                      result = %{
                        "did"         => did,
                        "normalized"  => normalize(did),
                        "formatted"   => Formatter.format(did),
                        "tollstate"   => tollstate(did),
                        "region"      => region(did),
                        "meta"        => %{
                          "country" => %{"name" => name, "iso" => iso},
                          "state"   => %{}
                        }
                      }

                      {:ok, result}
                  end

                false ->
                  # this can be caribbean which should be tagged as international
                  case is_nadp?(did) do
                    false -> {:error, :invalid_number_format}
                    true  ->
                      case Regex.named_captures(@nadp, did) do
                        nil -> {:error, :invalid_number_format}
                        res ->
                          case Numerus.Nadp.metadata(res["area_code"]) do
                            {:error, _} ->
                              result = %{
                                "did"         => did,
                                "normalized"  => normalize(did),
                                "formatted"   => Formatter.format(did),
                                "tollstate"   => tollstate(did),
                                "region"      => region(did),
                                "meta"        => %{}
                              }

                              {:ok, result}

                            {:ok, res} ->
                              result =
                                case Enum.member?(["US", "CA"], res["country_iso"]) do
                                  false ->
                                    %{
                                      "did"         => did,
                                      "normalized"  => normalize(did),
                                      "formatted"   => Formatter.format(did),
                                      "tollstate"   => tollstate(did),
                                      "region"      => region(did),
                                      "meta"        => %{
                                        "country" => %{
                                          "name"  => res["country_name"],
                                          "iso" => res["country_iso"]
                                        },
                                        "state"   => %{}
                                      }
                                    }
                                  true  ->
                                    %{
                                      "did"         => did,
                                      "normalized"  => normalize(did),
                                      "formatted"   => Formatter.format(did),
                                      "tollstate"   => tollstate(did),
                                      "region"      => region(did),
                                      "meta"        => %{
                                        "country" => %{
                                          "name"  => res["country_name"],
                                          "iso"   => res["country_iso"]
                                        },
                                        "state"   => %{
                                          "name"  => res["state_name"],
                                          "iso"   => res["state_iso"]
                                        }
                                      }
                                    }
                                end
                              {:ok, result}
                          end
                      end
                  end
              end
          end
        n when n in ["npan", "one_npan"]  -> metadata(Numerus.normalize(did))
        _ -> {:error, :invalid_number_format}
      end
    end
    def metadata(_), do: {:error, :invalid_number_format}

    # -- private functions -- #

    # return the region for the did
    @spec region(did :: bitstring()) :: bitstring()
    defp region(did) when is_bitstring(did) do
      cond do
        is_n11?(did)        -> "nadp"
        is_nadp?(did)       -> "nadp"
        is_shortcode?(did)  -> "nadp"
        is_usintl?(did)     -> "international"
        is_intl?(did)       -> "international"
        true                -> "unknown"
      end
    end
    defp region(_), do: "unknown"

    # return the formatting of the did
    @spec format(did :: bitstring()) :: bitstring()
    def format(did) when is_bitstring(did) do
      cond do
        is_n11?(did)        -> "n11"
        is_e164?(did)       -> "e164"
        is_npan?(did)       -> "npan"
        is_1npan?(did)      -> "one_npan"
        is_shortcode?(did)  -> "shortcode"
        is_usintl?(did)     -> "us_intl"
        true                -> "unknown"
      end
    end
    def format(_), do: "unknown"

    # return the tollstate for the supplied did
    @spec tollstate(did :: bitstring()) :: bitstring()
    defp tollstate(did) when is_bitstring(did) do
      cond do
        is_tollfree?(did)   -> "tollfree"
        is_shortcode?(did)  -> "shortcode"
        is_n11?(did)        -> service_did_info(did)
        is_premium?(did)    -> "premium"
        is_nadp?(did)       -> "standard"
        is_usintl?(did)     -> "international"
        is_intl?(did)       -> "international"
        true                -> "unknown"
      end
    end
    defp tollstate(_), do: "unknown"

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
    defp service_did_info(_), do: "unknown"
end
