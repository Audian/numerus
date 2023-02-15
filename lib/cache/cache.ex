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

defmodule Numerus.Cache do
  @moduledoc """
  Cache supervisor
  """

  require Logger
  use Supervisor

  # -- module attributes -- #
  @options  []

  # -- start and initialize -- #

  @doc "Start the server"
  def start_link(_options \\ []) do
    Logger.info(IO.ANSI.green() <> "Starting the cache supervisor.")
    Supervisor.start_link(__MODULE__, [], name: __MODULE__.Supervisor)
  end

  @impl true
  def init(_) do
    children  = [
      Numerus.Cache.Country,
      Numerus.Cache.Nadp
    ]

    options   = [strategy: :one_for_one]
    Supervisor.init(children, options)
  end

  # -- interface functions -- #
  @spec add(table :: atom(), key :: bitstring() | atom(), value :: any()) :: {:ok, any()} | {:error, term()}
  def add(table, key, value) do
    Cachex.put(table, key, value, @options)
  end

  @spec get(table :: atom(), key :: bitstring() | atom()) :: {:ok, any()} | {:error, term()}
  def get(table, key) do
    case Cachex.get(table, key) do
      {:ok, nil}  -> {:error, :not_found}
      {:ok, res}  -> {:ok, res}
    end
  end

  @spec del(table :: atom(), key :: bitstring() | atom()) :: {:ok, any()} | {:error, term()}
  def del(table, key) do
    case Cachex.get(table, key) do
      {:error, :not_found}  -> {:ok, :deleted}
      {:ok, _}  ->
        case Cachex.del(table, key) do
          {:ok, _}    -> {:ok, :deleted}
          {:error, _} -> {:error, :delete_failure}
        end
    end
  end
end
