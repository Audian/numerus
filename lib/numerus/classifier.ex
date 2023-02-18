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

  # define regexes for format types
  @e164     ~r/\A^\+[1-9][0-9][0-9]{8,13}$\z/
  @npan     ~r/\A^[2-9][0-9]{2}[2-9][0-9]{6}$\z/
  @one_npan ~r/\A^1[2-9][0-9]{2}[2-9][0-9]{6}$\z/

  @n11      ~r/\A^[2-9]11$\z/

  # parser regex
  # this regex splits the full did into country code + number
  @parser   ~r/(\+|011)(?<countrycode>9[976]\d|8[987530]\d|6[987]\d|5[90]\d|42\d|3[875]\d|2[98654321]\d|9[8543210]|8[6421]|6[6543210]|5[87654321]|4[987654310]|3[9643210]|2[70]|7|1)(?<number>\d{1,14})$/i

  # -- public functions  -- #

  @doc """
  Classify the supplied did. This function parses the did and returns a map with the
  formatting and region for the did. We consider 2 zones North American Dial plan and
  the rest of the world. This is because NADP contains multiple countries and have their
  own special considerations on classification.

  For more information about the DID, use Numerus.metadata/1
  """
  @spec classify(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def classify(did) when is_bitstring(did) do
    # get the formatting
    format =
      cond do
        is_n11?(did)        -> :n11
        is_e164?(did)       -> :e164
        is_1npan?(did)      -> :one_npan
        is_npan?(did)       -> :npan
        is_shortcode?(did)  -> :shortcode
        is_usintl?(did)     -> :us_intl
        true                -> :unknown
      end

    # get the region for this did, :nadp, or :world
    region = case is_nadp?(did) do
      true  -> :nadp
      false -> case String.match?(did, @intl_n) or String.match?(did, @intl) do
        true  -> :world
        false -> case format do
          :shortcode  -> :nadp
          :n11        -> :nadp
          _           -> :unknown
        end
      end
    end

    classification = %{"region" => region, "format" => format}
    {:ok, classification}
  end
  def classify(_), do: {:error, :invalid_number}

  # -- did classification functions -- #
  @doc """
  Return true if the did is an NXX dialing code. The NXX codes are part of
  the North American Dial Plan used for special local services.

  The services are:
  211 - Community Services
  311 - Municipal Government Services
  411 - Directory Information
  511 - Traffic Information
  611 - Telco customer service and repair
  711 - TDD and Relay
  811 - Public Utility location
  911 - Emergency services
  """
  @spec is_n11?(did :: bitstring()) :: boolean()
  def is_n11?(did) when is_bitstring(did) do
    String.match?(did, @n11)
  end
  def is_n11?(_), do: false

  @doc """
  Returns true if the supplied did belongs to the North American Dial Plan.
  """
  @spec is_nadp?(did :: bitstring() | integer()) :: boolean()
  def is_nadp?(did) when is_bitstring(did), do: String.match?(did, @nadp)
  def is_nadp?(_), do: false

  @doc """
  Returns true if the number is formatted E.164. This is just a check for E.164
  formatting and is not restricted to nadp numbers.
  """
  @spec is_e164?(did :: bitstring()) :: boolean()
  def is_e164?(did) when is_bitstring(did), do: String.match?(did, @e164)
  def is_e164?(_), do: false

  @doc """
  Returns true if the did is formatted E.164 and is part of the NADP
  """
  @spec is_use164?(did :: bitstring()) :: boolean()
  def is_use164?(did) when is_bitstring(did), do: String.match?(did, @nadp) and is_e164?(did)
  def is_use164?(_), do: false

  @doc """
  Returns true if the did is formatted NPAN
  """
  @spec is_npan?(did :: bitstring()) :: boolean()
  def is_npan?(did) when is_bitstring(did), do: String.match?(did, @npan)
  def is_npan?(_), do: false

  @doc """
  Returns true if the did is formatted 1NPAN
  """
  @spec is_1npan?(did :: bitstring()) :: boolean()
  def is_1npan?(did) when is_bitstring(did), do: String.match?(did, @one_npan)
  def is_1npan?(_), do: false

  @doc """
  Returns true if the supplied did is a toll free number.
  """
  @spec is_tollfree?(did :: bitstring()) :: boolean()
  def is_tollfree?(did) when is_bitstring(did), do: is_nadp?(did) && String.match?(did, @natf)
  def is_tollfree?(_), do: false

  @doc """
  Return true if the supplied did is a US shortcode. Shortcodes from other countries
  are not currently supported.
  """
  @spec is_shortcode?(did :: bitstring()) :: boolean()
  def is_shortcode?(did) when is_bitstring(did), do: String.match?(did, @scode)
  def is_shortcode?(_), do: false

  @doc """
  Returns true is the number is not part of the north american dial plan and is considered
  international.
  """
  @spec is_intl?(did :: bitstring()) :: boolean()
  def is_intl?(did) when is_bitstring(did) do
    String.match?(did, @intl) or is_usintl?(did)
  end

  @doc """
  Returns true if the number is a US formatted international number. This did begins
  with a 011 for international access.
  """
  @spec is_usintl?(did :: bitstring()) :: boolean()
  def is_usintl?(did) when is_bitstring(did) do
    String.match?(did, @intl_n)
  end
  def is_usintl?(_), do: false

  # -- did parsers -- #
  @doc """
  Split and extract the number into its country code and telephone number.

  Example:
  ```elixir
  iex> Numerus.Classifier.extract("+96824555555")
  {:ok, %{"countrycode" => "968", "number" => "24555555"}}

  iex> Numerus.Classifier.extract("+12065551212")
  {:ok, %{"countrycode" => "1", "number" => "2065551212"}}

  iex> Numerus.Classifier.extract("Random String here!")
  {:error, :invalid_number_format}
  ```
  """
  @spec extract(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def extract(did) when is_bitstring(did) do
    case Regex.named_captures(@parser, did) do
      nil -> {:error, :invalid_number_format}
      res -> {:ok, res}
    end
  end

  def extract(_), do: {:error, :invalid_number_format}

  @doc """
  Split a did from the North American Dial Plan into its components.

  Example:
  ```elixir
  iex> Numerus.Classifier.split("+12065551212")
  {:ok, %{"area_code" => "206", "exch" => "555", "number" => "1212"}}

  iex> Numerus.Classifier.split("12065551212")
  {:ok, %{"area_code" => "206", "exch" => "555", "number" => "1212"}}

  iex> Numerus.Classifier.split("2065551212")
  {:ok, %{"area_code" => "206", "exch" => "555", "number" => "1212"}}
  ```
  """
  @spec split(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def split(did) when is_bitstring(did) do
    case Regex.named_captures(@nadp, did) do
      nil -> {:error, :invalid_number_format}
      res -> {:ok, res}
    end
  end
  def split(_), do: {:error, :invalid_number_format}

  @doc """
  Normalize the did. This converts the did to E164
  """
  @spec normalize(did :: bitstring(), format :: atom() | nil) :: bitstring() | :error
  def normalize(did, format) do
    case format do
      :e164     -> Formatter.to_e164(did)
      :npan     -> Formatter.to_npan(did)
      :one_npan -> Formatter.to_1npan(did)
      _         -> :error
    end
  end

  def normalize(did), do: normalize(did, :e164)

  # -- metadata functions -- #

  @doc """
  Return metadata about the supplied did
  """
  @spec metadata(did :: bitstring()) :: {:ok, map()} | {:error, term()}
  def metadata(did) when is_bitstring(did) do
    case classify(did) do
      {:ok, _} ->
        case extract(did) do
          {:ok, extracted} ->
            case extracted["countrycode"] do
              "1" ->
                # this is a north american number under the NADP
                case split(did) do
                  {:error, _} -> {:error, :invalid_number}
                  {:ok, number} ->
                    case Numerus.Nadp.metadata(number["area_code"]) do
                      {:error, _} -> {:error, :invalid_number}
                      {:ok, meta} ->
                        result =
                          %{
                            "did"       => did,
                            "formatted" => Formatter.format(did),
                            "meta"      => %{
                              "country" => %{
                                "name"  => meta["country_name"],
                                "iso"   => meta["country_iso"]
                              },
                              "state"   => %{
                                "name"  => meta["state_name"],
                                "iso"   => meta["state_iso"]
                              }
                            }
                          }
                        {:ok, result}
                    end
                end
              num ->
                case Numerus.Country.metadata(num) do
                  {:error, _} -> {:error, :not_found}
                  {:ok, meta} ->
                    result =
                      %{
                        "did"       => did,
                        "formatted" => Formatter.format(did),
                        "meta"      => %{
                          "country" => %{
                            "name"  => meta["name"],
                            "iso"   => meta["iso"]
                          },
                          "state"   => %{}
                        }
                      }
                    {:ok, result}
                end
            end
          {:error, _} -> {:error, :invalid_number}
        end
      {:error, :invalid_number} -> {:error, :invalid_number}
    end
  end
  def metadata(_), do: {:error, :invalid_number}
end
