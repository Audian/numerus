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

defmodule NumerusTest do
  use ExUnit.Case
  doctest Numerus.Classifier
  doctest Numerus.Formatter

  require Logger

  @e164_dids      ["+12065551212", "+4402955555555"]
  @npan_dids      ["2065551212"]
  @one_npan_dids  ["12065551212"]
  @tollfree_dids  [
    "+18005551212",
    "+18885551212",
    "+18775551212",
    "+18665551212",
    "+18555551212",
    "+18445551212",
    "+18335551212",
    "18005551212",
    "8885551212"
  ]
  @premium_dids   [
    "+19005551212",
    "19005551212",
    "9005551212"
  ]

  @garbage_data   [nil, "randomstr", 1923, 0.0449]

  test "e164 match test" do
    @e164_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_e164?(x) == true
    end)
  end

  test "e164 non match test" do
    @npan_dids ++ @one_npan_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_e164?(x) == false
    end)
  end

  test "npan match test" do
    @npan_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_npan?(x) == true
    end)
  end

  test "npan non match test" do
    @e164_dids ++ @one_npan_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_npan?(x) == false
    end)
  end

  test "one npan match test" do
    @one_npan_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_1npan?(x) == true
    end)
  end

  test "one npan non match test" do
    @npan_dids ++ @e164_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_1npan?(x) == false
    end)
  end

  test "tollfree number match" do
    @tollfree_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_tollfree?(x) == true
    end)
  end

  test "premium rate number match" do
    @premium_dids
    |> Enum.each(fn x ->
      assert Numerus.Classifier.is_premium?(x) == true
    end)
  end

  test "split and format nadp numbers" do
    did1 = "2063130566"
    did2 = "12063130566"
    did3 = "+12063130566"
    did4 = "+96824560742"
    did5 = "98765"
    did6 = "711"
    nadp = "+1 (206) 313 0566"
    intl = "+968 24560742"

    assert Numerus.Formatter.format(did1) == nadp
    assert Numerus.Formatter.format(did2) == nadp
    assert Numerus.Formatter.format(did3) == nadp
    assert Numerus.Formatter.format(did4) == intl
    assert Numerus.Formatter.format(did5) == did5
    assert Numerus.Formatter.format(did6) == did6
  end

  test "Lookup country from cache" do
    {:ok, result} = Numerus.Cache.get(:cache_country, "91")
    assert result["iso"]  == "IN"
    assert result["name"] == "India"
  end

  test "Lookup nadp from cache" do
    {:ok, result1} = Numerus.Cache.get(:cache_nadp, "201")
    assert result1["state_iso"]     == "NJ"
    assert result1["state_name"]    == "New Jersey"

    {:ok, result2} = Numerus.Cache.get(:cache_nadp, "246")
    assert result2["state_iso"]     == ""
    assert result2["state_name"]    == ""
    assert result2["country_iso"]   == "BB"
    assert result2["country_name"]  == "Barbados"
  end

  test "non parseable dids" do
    @garbage_data
    |> Enum.each(fn x ->
      assert Numerus.Classifier.extract(x) == {:error, :invalid_number_format}
    end)
  end
end
