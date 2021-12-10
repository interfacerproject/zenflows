defmodule Zenflows.Ecto.Id do
@moduledoc """
An Ecto type to Base.url_encode64/2 UUIDs.  It provides validation for
ids in GraphQL schemas and just makes the ids shorter.
"""

use Ecto.Type

@typedoc "URL-safe Base64-encoded string."
@type t() :: <<_::176>> # 22*8

@typedoc "A raw binary representation of a UUID."
@type raw() :: Ecto.UUID.raw()

@impl true
def type() do
	:uuid
end

# credo:disable-for-lines:3 Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-lines:7 Credo.Check.Consistency.TabsOrSpaces
@impl true
def cast(<<c01::8, c02::8, c03::8, c04::8,
           c05::8, c06::8, c07::8, c08::8,
           c09::8, c10::8, c11::8, c12::8,
           c13::8, c14::8, c15::8, c16::8,
           c17::8, c18::8, c19::8, c20::8,
           c21::8, c22::8>> = val) do
	valid? = v(c01) and v(c02) and v(c03) and v(c04)
		and v(c05) and v(c06) and v(c07) and v(c08)
		and v(c09) and v(c10) and v(c11) and v(c12)
		and v(c13) and v(c14) and v(c15) and v(c16)
		and v(c17) and v(c18) and v(c19) and v(c20)
		and v(c21) and v(c22)
	if valid? do
		{:ok, val}
	else
		:error
	end
end

def cast(<<_::128>> = raw) do
	{:ok, encode(raw)}
end

def cast(_) do
	:error
end

@impl true
def dump(id) when byte_size(id) == 22 do
	decode(id)
end

def dump(_) do
	:error
end

@impl true
def load(<<_::128>> = raw) do
	{:ok, encode(raw)}
end

def load(_) do
	:error
end

@impl true
def autogenerate() do
	gen()
end

@doc "Generates a random UUIDv4 encoded as URL-safe Base64 string."
@spec gen() :: t()
def gen() do
	encode(bingen())
end

@doc "Generates a random UUIDv4 in binary format."
@spec bingen() :: raw()
def bingen() do
	Ecto.UUID.bingenerate()
end

@spec decode(String.t()) :: {:ok, raw()} | :error
defp decode(str) do
	case Base.url_decode64(str, padding: false) do
		{:ok, raw} -> {:ok, raw}
		:error -> :error
	end
end

@spec encode(raw()) :: t()
defp encode(raw) do
	Base.url_encode64(raw, padding: false)
end

@compile {:inline, v: 1}
@spec v(any()) :: boolean()
defp v(?_), do: true
defp v(?-), do: true
defp v(?0), do: true
defp v(?1), do: true
defp v(?2), do: true
defp v(?3), do: true
defp v(?4), do: true
defp v(?5), do: true
defp v(?6), do: true
defp v(?7), do: true
defp v(?8), do: true
defp v(?9), do: true
defp v(?A), do: true
defp v(?B), do: true
defp v(?C), do: true
defp v(?D), do: true
defp v(?E), do: true
defp v(?F), do: true
defp v(?G), do: true
defp v(?H), do: true
defp v(?I), do: true
defp v(?J), do: true
defp v(?K), do: true
defp v(?L), do: true
defp v(?M), do: true
defp v(?N), do: true
defp v(?O), do: true
defp v(?P), do: true
defp v(?Q), do: true
defp v(?R), do: true
defp v(?S), do: true
defp v(?T), do: true
defp v(?U), do: true
defp v(?V), do: true
defp v(?W), do: true
defp v(?X), do: true
defp v(?Y), do: true
defp v(?Z), do: true
defp v(?a), do: true
defp v(?b), do: true
defp v(?c), do: true
defp v(?d), do: true
defp v(?e), do: true
defp v(?f), do: true
defp v(?g), do: true
defp v(?h), do: true
defp v(?i), do: true
defp v(?j), do: true
defp v(?k), do: true
defp v(?l), do: true
defp v(?m), do: true
defp v(?n), do: true
defp v(?o), do: true
defp v(?p), do: true
defp v(?q), do: true
defp v(?r), do: true
defp v(?s), do: true
defp v(?t), do: true
defp v(?u), do: true
defp v(?v), do: true
defp v(?w), do: true
defp v(?x), do: true
defp v(?y), do: true
defp v(?z), do: true
defp v(_), do: false
end
