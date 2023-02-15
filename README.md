# Numerus

Numerus is a number classification, conversion and formatting library. This
library performs the following tasks.

+ Convert between formats such as E.164, NPAN and 1NPAN.
+ Classify region of the did, i.e North American Dial Plan or other.
+ Classify format of the did, i.e E.164, NPAN and 1NPAN.
+ Classify toll/toll-free status of the did within the NADP region.

Numerus can also be used to generate metadata about the did with the classification data
and country specific info such as name and iso2.

```elixir
iex> Numerus.metadata("+12065551212")
{:ok,
 %{
    "did" => "+12065551212",
    "formatted" => "+1 (206) 555 1212",
    "meta" => %{
      "country" => %{
        "iso" => "US",
        "name" => "United States"
      },
    "state" => %{
      "iso" => "WA",
      "name" => "Washington"
    }
   }
 }}

```

## Installation
You can add this to your project by adding the following to mix.exs

```elixir
def deps do
  [
    {:numerus,  github: "Audian/numerus"}
  ]
end
```

## Documentation

You can generate docs by running the following.

```bash
mix docs
```
