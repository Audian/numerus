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

defmodule Numerus.MixProject do
  use Mix.Project

  def project do
    [
      app: :numerus,
      version: "0.6.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Numerus",
      # keep the Dialyzer PLTs in a stable local dir (not the volatile _build)
      # so they can be cached across CI runs
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path:  "priv/plts"
      ],
      docs: [
        main: "Numerus",
        extras: ["README.md"]
      ]
    ]
  end

  # Run the precommit alias in MIX_ENV=test so its `test` step (and the
  # quality tools, which are available in :dev and :test) run in one env.
  def cli do
    [preferred_envs: [precommit: :test]]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod:                {Numerus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason,        "~> 1.0"},
      {:csv,          "~> 3.0"},
      {:cachex,       "~> 4.1"},

      # code quality, static checks and documentation
      # only needed in dev and test environments.
      {:dialyxir,     "~> 1.4",   [only: [:dev, :test], runtime: false]},
      {:credo,        "~> 1.7",   [only: [:dev, :test], runtime: false]},
      {:ex_doc,       "~> 0.38",  [only: [:dev, :test], runtime: false]},
      {:sobelow,      "~> 0.14",  [only: [:dev, :test], runtime: false]},
      {:mix_audit,    "~> 2.1",   [only: [:dev, :test], runtime: false]},
      {:yaml_elixir,  "~> 2.11",  [only: [:dev, :test], override: true]}
    ]
  end

  # Run "mix help aliases" to learn about aliases.
  defp aliases do
    [
      # Pre-commit gate: run the same checks CI runs, in order, and fail on
      # any drift instead of silently rewriting files. Run with `mix precommit`.
      precommit: [
        # `mix_audit` checks mix.lock against the security-advisories DB;
        # a stale tree with a new CVE fails here and forces `mix deps.update`.
        "deps.audit",
        # treat compiler warnings as errors to be fixed
        "compile --warnings-as-errors",
        # validation-only: fail on unused lock entries rather than mutating
        # mix.lock (unlike the default `deps.unlock --unused`).
        "deps.unlock --check-unused",
        # refactoring / consistency findings across the codebase
        "credo",
        # exit code gated by the `exit:` level in .sobelow-conf
        "sobelow --config .sobelow-conf",
        # typespec / pattern-match contradictions; PLTs live under priv/plts
        "dialyzer",
        # runs in :test via preferred_envs above (see cli/0)
        "test"
      ]
    ]
  end
end
