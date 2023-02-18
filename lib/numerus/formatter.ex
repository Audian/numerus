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

defmodule Numerus.Formatter do

  @moduledoc """
  This module provides formatting and format conversion functions between
  the standard E.164 and North American Dial Plan Dids.
  """

  require Logger

  alias Numerus.Classifier, as: Classifier

  # -- module attributes -- #
  @normal_format  :e164

  # -- format functions  -- #

  @doc """
  Normalize the did into the supplied normalization format. If no format is
  provided when called, @normal_format is used. Shortcodes passed to the
  converter will always return the shortcode as-is.

  Example:
  ```elixir
  iex> Numerus.Formatter.normalize("2065551212")
  "+12065551212"

  iex> Numerus.Formatter.normalize("12065551212")
  "+12065551212"

  iex> Numerus.Formatter.normalize("98655") # shortcode
  "98655"

  iex> Numerus.Formatter.normalize("+12065551212", :one_npan)
  "12065551212"
  ```

  iex> Numerus.Formatter.normalize("98655", :e164)
  {:error, :invalid_format}
  """
  @spec normalize(did :: bitstring, format :: atom() | nil) :: bitstring() | {:error, :invalid_format}
  def normalize(did, format) when is_bitstring(did) and is_atom(format) do
    case format do
      :e164       -> to_e164(did)
      :npan       -> to_npan(did)
      :one_npan   -> to_1npan(did)
      :us_intl    -> to_usintl(did)
      :shortcode  ->
        # we need to verify that the supplied number is a shortcode. If so,
        # return the did, if not, then return an error as this conversion is
        # not possible.
        case Classifier.classify(did) do
          {:ok, %{"region" => _, "format" => format}} ->
            case format do
              :shortcode  -> did
              :n11        -> did
              _           -> {:error, :invalid_format}
            end
        end
        _ -> {:error, :invalid_format}
    end
  end

  def normalize(_,_), do: {:error, :invalid_format}

  def normalize(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => _, "format" => format}} ->
        if format == :shortcode or format == :n11 do
          did
        else
          normalize(did, @normal_format)
        end
      _ -> {:error, :invalid_format}
    end
  end
  def normalize(_), do: {:error, :invalid_format}

  @doc """
  Pretty format a telephone number. For NADP numbers. Other numbers will
  be returned with the country code separated from the main number.
  """
  @spec format(did :: bitstring()) :: bitstring() | {:error, :invalid_format}
  def format(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => region, "format" => _}} ->
        case region do
          :nadp   ->
            case Classifier.split(did) do
              {:error, _}   -> did
              {:ok, result} ->
                "+1 (#{result["area_code"]}) #{result["exch"]} #{result["number"]}"
            end
          :world  ->
            case Classifier.extract(did) do
              {:error, _}   -> did
              {:ok, result} ->
                # we have a country code and did
                "+#{result["countrycode"]} #{result["number"]}"
            end
        end
      _ -> did
    end
  end
  def format(_), do: {:error, :invalid_format}

  # -- convert functions -- #

  @doc """
  Convert the supplied did to E.164
  """
  @spec to_e164(did :: bitstring()) :: bitstring() | {:error, :invalid_format}
  def to_e164(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => _, "format" => format}} ->
        case format do
          :e164       -> did
          :one_npan   -> "+#{did}"
          :npan       -> "+1#{did}"
          :us_intl    -> String.replace(did, ~r/^011/, "+")
          _           -> {:error, :invalid_format}
        end
      _ ->
        # we do not convert other formats, so just return an error.
        :error
    end
  end

  def to_e164(_), do: :error

  @doc """
  Convert the supplied did to npan
  """
  @spec to_npan(did :: bitstring()) :: bitstring() | {:error, :invalid_format}
  def to_npan(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => region, "format" => format}} ->
        case region do
          :world ->
            # npan is exclusively for NADP regions
            :error
          :nadp ->
            # nadp numbers can be converted to npan or 1npan
            case format do
              :e164     -> String.replace(did, ~r/\+1/, "")
              :one_npan -> String.replace(did, ~r/^1/,  "")
              :npan     -> did
              _         -> {:error, :invalid_format}
            end

          _ -> {:error, :invalid_format}
        end
      _ ->
        # we do not convert other regions. just return an error.
        :error
    end
  end
  def to_npan(_), do: {:error, :invalid_format}

  @doc """
  Convert the supplied did to 1npan
  """
  @spec to_1npan(did :: bitstring()) :: bitstring() | {:error, :invalid_format}
  def to_1npan(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => region, "format" => format}} ->
        case region do
          :world ->
            # npan is exclusively for NADP regions
            :error
          :nadp ->
            # nadp numbers can be converted to npan or 1npan
            case format do
              :e164     -> String.replace(did, ~r/\+/, "")
              :one_npan -> did
              :npan     -> "1#{did}"
              _         -> {:error, :invalid_format}
            end

          _ -> {:error, :invalid_format}
        end
      _ ->
        # we do not convert other regions. just return an error.
        :error
    end
  end
  def to_1npan(_), do: {:error, :invalid_format}

  @doc """
  Convert the supplied did to us intl format.
  """
  @spec to_usintl(did :: bitstring()) :: bitstring() | :error
  def to_usintl(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => region, "format" => format}} ->
        case region do
          :nadp   -> :error
          :world  ->
            case format do
              :us_intl  -> did
              :e164     -> String.replace(did, ~r/\+/, "011")
              _         -> {:error, :invalid_format}
            end
          _ -> {:error, :invalid_format}
        end
    end
  end
  def to_usintl(_), do: {:error, :invalid_format}

  # -- format  functions -- #
end
