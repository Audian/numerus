#!/usr/bin/env python3
"""
Regenerate the reference fixtures that test/reference_data_test.exs checks
Numerus' priv/cache CSVs against.

The reference is Google's libphonenumber (https://github.com/google/libphonenumber).
Download the two source files first, then run this script:

    B=https://raw.githubusercontent.com/google/libphonenumber/master/resources
    curl -sfo PhoneNumberMetadata.xml "$B/PhoneNumberMetadata.xml"
    curl -sfo geo1.txt "$B/geocoding/en/1.txt"
    python3 scripts/reference_fixtures.py PhoneNumberMetadata.xml geo1.txt

It writes:

  test/fixtures/reference_area_codes.csv
      one row per US/Canada area code in libphonenumber's geocoding data.
  test/fixtures/reference_country_codes.csv
      one row per fixed-line/mobile example number in libphonenumber's
      metadata, with the country (and state, for +1) Numerus should return.

Numerus-specific decisions encoded here:

  * Shared dial codes resolve to libphonenumber's `mainCountryForCode`
    (e.g. +39 -> IT, +7 -> RU, +44 -> GB). Numerus has no number-range data.
  * US territories on +1 (PR, VI, GU, MP, AS) are country US with the
    territory as the state.
  * Where libphonenumber names several provinces for one area code
    (867, 902/782) any of them is accepted; the state column is `A|B|C`.
"""

import csv
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(ROOT, "test", "fixtures")

US_TERRITORIES = {"PR", "VI", "GU", "MP", "AS"}

STATES = {
    # US
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
    "California": "CA", "Colorado": "CO", "Connecticut": "CT",
    "Delaware": "DE", "Washington D.C.": "DC", "Florida": "FL",
    "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID", "Illinois": "IL",
    "Indiana": "IN", "Iowa": "IA", "Kansas": "KS", "Kentucky": "KY",
    "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
    "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN",
    "Mississippi": "MS", "Missouri": "MO", "Montana": "MT",
    "Nebraska": "NE", "Nevada": "NV", "New Hampshire": "NH",
    "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
    "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH",
    "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA",
    "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
    "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT",
    "Virginia": "VA", "Washington State": "WA", "West Virginia": "WV",
    "Wisconsin": "WI", "Wyoming": "WY",
    # Canada
    "Alberta": "AB", "British Columbia": "BC", "British Colombia": "BC",
    "Manitoba": "MB", "New Brunswick": "NB",
    "Newfoundland and Labrador": "NL", "Ontario": "ON", "Quebec": "QC",
    "Saskatchewan": "SK",
    "Northwest Territories/Nunavut/Yukon": "NT|NU|YT",
    "Nova Scotia/Prince Edward Island": "NS|PE",
}

CANADA = {"AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"}


def state_for(name):
    # city-level entries such as "Chicago, IL" carry the state as a suffix
    m = re.match(r"^.+, ([A-Z]{2})$", name)
    if m:
        return m.group(1)
    if name not in STATES:
        sys.exit(f"unmapped geocoding name: {name!r}")
    return STATES[name]


def area_codes(geo_path):
    out = {}
    with open(geo_path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^1([2-9]\d\d)\|(.+)$", line.strip())
            if m:
                state = state_for(m.group(2))
                country = "CA" if state.split("|")[0] in CANADA else "US"
                out[m.group(1)] = (country, state)
    return out


def country_examples(meta_path, npas):
    root = ET.parse(meta_path).getroot()
    territories = [t for t in root.iter("territory") if re.fullmatch(r"[A-Z]{2}", t.get("id"))]

    by_code = {}
    for t in territories:
        by_code.setdefault(t.get("countryCode"), []).append(t)

    def main_for(code):
        group = by_code[code]
        if len(group) == 1:
            return group[0].get("id")
        mains = [t.get("id") for t in group if t.get("mainCountryForCode") == "true"]
        assert len(mains) == 1, (code, mains)
        return mains[0]

    rows = []
    for t in territories:
        region, code = t.get("id"), t.get("countryCode")
        for kind in ("fixedLine", "mobile"):
            ex = t.find(f"{kind}/exampleNumber")
            if ex is None:
                continue
            number = f"+{code}{ex.text}"
            if code == "1":
                npa = ex.text[:3]
                if region in ("US", "CA"):
                    country, state = npas[npa]
                elif region in US_TERRITORIES:
                    country, state = "US", region
                else:
                    country, state = region, ""
            else:
                country, state = main_for(code), ""
            rows.append((region, kind, number, country, state))
    return rows


def main(meta_path, geo_path):
    # build and validate both datasets before touching either fixture, so a
    # failure leaves the existing fixtures intact rather than half-updated
    npas = area_codes(geo_path)
    examples = sorted(country_examples(meta_path, npas))

    os.makedirs(FIXTURES, exist_ok=True)

    with open(os.path.join(FIXTURES, "reference_area_codes.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["npa", "country_iso", "state_iso"])
        for npa in sorted(npas):
            w.writerow([npa, *npas[npa]])

    with open(os.path.join(FIXTURES, "reference_country_codes.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["region", "kind", "number", "country_iso", "state_iso"])
        w.writerows(examples)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
