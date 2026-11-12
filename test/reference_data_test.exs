defmodule Numerus.ReferenceDataTest do
  @moduledoc """
  Checks the priv/cache CSVs against reference data generated from Google's
  libphonenumber (see scripts/reference_fixtures.py). A stale or wrong row in
  nadp.csv or country.csv fails here instead of silently producing a number
  with no country.
  """
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures", __DIR__)

  defp fixture(name) do
    @fixtures
    |> Path.join(name)
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.to_list()
  end

  # `state_iso` may list several accepted values as "A|B|C"
  defp state_ok?(expected, actual), do: actual in String.split(expected, "|")

  defp country_state(did) do
    {:ok, m} = Numerus.metadata(did)
    {get_in(m, ["meta", "country", "iso"]), get_in(m, ["meta", "state", "iso"]) || ""}
  end

  test "every US/Canada area code resolves to the right country and state" do
    failures =
      for %{"npa" => npa, "country_iso" => country, "state_iso" => state} <- fixture("reference_area_codes.csv"),
          {got_country, got_state} = country_state("+1#{npa}5550100"),
          got_country != country or not state_ok?(state, got_state) do
        "#{npa}: expected #{country}/#{state}, got #{inspect(got_country)}/#{inspect(got_state)}"
      end

    assert failures == [], "#{length(failures)} area codes wrong:\n" <> Enum.join(failures, "\n")
  end

  test "every country's example numbers resolve to the right country" do
    failures =
      for %{"region" => region, "number" => number, "country_iso" => country, "state_iso" => state} <-
            fixture("reference_country_codes.csv"),
          {got_country, got_state} = country_state(number),
          got_country != country or not state_ok?(state, got_state) do
        "#{region} #{number}: expected #{country}/#{state}, got #{inspect(got_country)}/#{inspect(got_state)}"
      end

    assert failures == [], "#{length(failures)} numbers wrong:\n" <> Enum.join(failures, "\n")
  end

  describe "country.csv" do
    test "each dial code is loaded exactly once" do
      {:ok, data} = Numerus.Country.data()
      keys = Enum.map(data, &elem(&1, 0))
      assert keys -- Enum.uniq(keys) == []
    end

    test "rows without a real dial code are not loaded" do
      {:ok, data} = Numerus.Country.data()
      refute Enum.any?(data, fn {code, _} -> code in ["", "0"] end)
    end

    test "shared dial codes return the explicitly marked main country" do
      for {code, iso} <- [{"39", "IT"}, {"7", "RU"}, {"44", "GB"}, {"61", "AU"}, {"64", "NZ"},
                          {"262", "RE"}, {"599", "CW"}, {"672", "NF"}] do
        assert {:ok, %{"iso" => ^iso}} = Numerus.Country.metadata(code), "+#{code} should be #{iso}"
      end
    end
  end

  test "US Virgin Islands has its own state name" do
    {:ok, area} = Numerus.Nadp.metadata("340")
    assert area["state_iso"] == "VI"
    assert area["state_name"] == "U.S. Virgin Islands"
  end
end
