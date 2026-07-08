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

defmodule Numerus do
  @moduledoc """
  Numerus
  -------

  Numerus is a telephone number parser and converter library.

  The library will allow you to convert between E.164 and NADP formats such as
  NPAN, 1NPAN as well as into a human readable format for output.

  Some metadata information can be gathered such as state, country.
  """

  require Logger

  # -- aliases -- #
  alias Numerus.Classifier, as: Classifier

  # -- module attributes -- #
  @app  Numerus.MixProject.project()[:app]
  @ver  Numerus.MixProject.project()[:version]

  # -- public functions -- #

  @doc "Return library version"
  @spec version() :: bitstring()
  def version(), do: "#{@app}-#{@ver}"

  # -- normalization functions -- #

  # -- interface functions  -- #

  @doc "Return true if the supplied did is E.164 formatted."
  @spec e164?(did :: bitstring()) :: boolean()
  def e164?(did), do: Classifier.e164?(did)

  @doc "Return true if the supplied did is NPAN formatted."
  @spec npan?(did :: bitstring()) :: boolean()
  def npan?(did), do: Classifier.npan?(did)

  @doc "Return true if the supplied did is 1NPAN formatted."
  @spec one_npan?(did :: bitstring()) :: boolean()
  def one_npan?(did), do: Classifier.one_npan?(did)

  @doc "Return true if the supplied did is a tollfree number"
  @spec tollfree?(did :: bitstring()) :: boolean()
  def tollfree?(did), do: Classifier.tollfree?(did)

  @doc "Return true if the supplied did belongs to the NADP"
  @spec nadp?(did :: bitstring()) :: boolean()
  def nadp?(did), do: Classifier.nadp?(did)

  @doc "Return true if the supplied number is a us short code."
  @spec shortcode?(did :: bitstring()) :: boolean()
  def shortcode?(did), do: Classifier.shortcode?(did)

  @doc "Normalize the DID"
  @spec normalize(did :: bitstring() | integer()) :: bitstring() | :error
  def normalize(did) when is_bitstring(did) do
    Numerus.Formatter.normalize(did)
  end
  def normalize(did) when is_integer(did) do
    normalize("#{did}")
  end
  def normalize(_), do: :error

  @doc "Classify the DID"
  @spec classify(did :: bitstring() | integer()) :: {:ok, map()} | {:error, term()}
  def classify(did) when is_bitstring(did) do
    Numerus.Classifier.classify(did)
  end
  def classify(did) when is_integer(did) do
    classify("#{did}")
  end
  def classify(_), do: {:error, :invalid_did}

  @doc "Return metadata for the number"
  @spec metadata(did :: bitstring() | integer()) :: {:ok, map()} | {:error, term()}
  def metadata(did) when is_bitstring(did) do
    Numerus.Classifier.metadata(did)
  end
  def metadata(did) when is_integer(did) do
    metadata("#{did}")
  end
  def metadata(_), do: {:error, :invalid_did}
end
