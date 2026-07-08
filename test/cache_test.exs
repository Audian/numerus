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

defmodule Numerus.CacheTest do
  use ExUnit.Case, async: false

  alias Numerus.Cache

  # an isolated, running cache table for round-trip tests
  @table :numerus_cache_test
  # a table that is deliberately never started, to exercise Cachex error tuples
  @dead_table :numerus_cache_never_started

  setup do
    # start_supervised! tears the table down after each test, keeping tests
    # isolated and avoiding any collision with the app's warmed caches
    start_supervised!(%{
      id: @table,
      start: {Cachex, :start_link, [@table, []]}
    })

    :ok
  end

  describe "get/2" do
    test "returns {:error, :not_found} for a key that is not present" do
      assert {:error, :not_found} = Cache.get(@table, "missing")
    end

    test "returns {:ok, value} for a key that is present" do
      {:ok, true} = Cache.add(@table, "key", "value")
      assert {:ok, "value"} = Cache.get(@table, "key")
    end

    test "returns an error tuple (does not raise) when the table is not running" do
      # before the fix this raised CaseClauseError because Cachex.get can
      # return {:error, :no_cache} and no clause matched it
      assert {:error, _reason} = Cache.get(@dead_table, "key")
    end
  end

  describe "del/2" do
    test "returns {:ok, :deleted} for a key that is not present" do
      # routes through Numerus.Cache.get/2, so a miss becomes {:error, :not_found}
      assert {:ok, :deleted} = Cache.del(@table, "missing")
    end

    test "deletes an existing key" do
      {:ok, true} = Cache.add(@table, "key", "value")
      assert {:ok, :deleted} = Cache.del(@table, "key")
      assert {:error, :not_found} = Cache.get(@table, "key")
    end

    test "returns an error tuple (does not raise) when the table is not running" do
      assert {:error, _reason} = Cache.del(@dead_table, "key")
    end
  end
end
