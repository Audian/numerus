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

defmodule Numerus.Country do
  @moduledoc """
  Country

  Numerus Country lookup module.
  """

  require Logger

  # -- public functions -- #

  @doc """
  Return metadata about the supplied country phone code. North American countries
  with country code of 1 are not returned in this result.

  Example:
  ```elixir
  iex> Numerus.Country.metadata("968")
  {:ok, %{"iso" => "OM", "iso3" => "OMN", "name" => "Oman"}}

  iex> Numerus.Country.metadata("999")
  {:error, :not_found}

  iex> Numerus.Country.metadata("1")
  {:error, :not_found}
  ```
  """
  @spec metadata(phonecode :: integer() | bitstring()) :: {:ok, map()} | {:error, term()}
  def metadata(phonecode) when is_bitstring(phonecode) do
    Numerus.Cache.get(:cache_country, phonecode)
  end

  def metadata(phonecode) when is_integer(phonecode) do
    phonecode
    |> to_string()
    |> metadata()
  end

  def metadata(_), do: {:error, :not_found}

  @doc "Generate data to be loaded into the cache"
  @spec data() :: {:ok, list()} | {:error, term()}
  def data() do
    datasource  = Path.join(:code.priv_dir(:numerus), "/cache/country.csv")

    case File.exists?(datasource) do
      false ->
        Logger.error("Unable to load datasource csv.")
        {:error, :enoent}
      true  ->
        Logger.info("Loading data from country.csv")

        data =
          datasource
          |> File.stream!()
          |> CSV.decode!(headers: true)
          |> Enum.map(&remap/1)

        {:ok, data}
    end
  end

  # -- private functions -- #

  @spec remap(map :: map()) :: tuple()
  defp remap(map) when is_map(map) do
    {
      map["phonecode"],
      %{
        "iso"   => map["iso"],
        "iso3"  => map["iso3"],
        "name"  => map["nicename"]
      }
    }
  end
end
