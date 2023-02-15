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

defmodule Numerus.Cache.Warmer do
  @moduledoc """
  Loads Country and NADP data into their respective caches
  """

  require Logger
  use Cachex.Warmer

  # -- public functions -- #

  @doc """
  Returns the interval for this warmer.
  """
  @spec interval() :: non_neg_integer()
  def interval, do: :timer.seconds(86_400)

  @doc """
  Execute the data fetch for the warmup.
  """
  @spec execute(args :: atom()) :: {:ok, [{key :: any(), value :: any()}]}
  def execute(args) do
    case data(args) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, []}
    end
  end


  # -- private functions -- #

  # return the data for the supplied context
  @spec data(context :: atom()) :: {:ok, list()} | {:error, term()}
  defp data(context) do
    case context do
      :country  -> Numerus.Country.data()
      :nadp     -> Numerus.Nadp.data()
      _         -> {:error, :invalid_context}
    end
  end
end
