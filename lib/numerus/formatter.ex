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

  # -- format functions  -- #

  @doc """
  Pretty format a telephone number. For NADP numbers. Other numbers will
  be returned with the country code separated from the main number.
  """
  @spec format(did :: bitstring()) :: bitstring() | :error
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
  def format(_), do: :error

  # -- convert functions -- #

  @doc """
  Convert the supplied did to E.164
  """
  @spec to_e164(did :: bitstring()) :: bitstring() | :error
  def to_e164(did) when is_bitstring(did) do
    case Classifier.classify(did) do
      {:ok, %{"region" => _, "format" => format}} ->
        case format do
          :e164       -> did
          :one_npan   -> "+#{did}"
          :npan       -> "+1#{did}"
          :us_intl    -> String.replace(did, ~r/^011/, "+")
          _           -> :error
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
  @spec to_npan(did :: bitstring()) :: bitstring() | :error
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
            end
        end
      _ ->
        # we do not convert other regions. just return an error.
        :error
    end
  end
  def to_npan(_), do: :error

  @doc """
  Convert the supplied did to 1npan
  """
  @spec to_1npan(did :: bitstring()) :: bitstring() | :error
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
            end
        end
      _ ->
        # we do not convert other regions. just return an error.
        :error
    end
  end
  def to_1npan(_), do: :error

  # -- format  functions -- #
end
