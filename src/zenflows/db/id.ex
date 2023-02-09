# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.DB.ID do
@moduledoc """
An Ecto type that implements ULIDs with Crockford's Base32.  It also
provides validation for IDs in GraphQL schemas.
"""

use Ecto.Type

@typedoc "A Crockford's Base32-encoded string."
@type t() :: <<_::208>> # 26*8

@typedoc "A raw binary representation of a ULID."
@type raw() :: <<_::128>>

@impl true
def type(), do: :uuid

@impl true
def cast(<<_::208>> = data) do
	with {:ok, _} <- decode(data) do
		{:ok, data}
	end
end
def cast(<<_::128>> = raw), do: encode(raw)
def cast(_), do: :error

@impl true
def dump(id) when byte_size(id) == 26, do: decode(id)
def dump(_), do: :error

@impl true
def load(<<_::128>> = raw), do: encode(raw)
def load(_), do: :error

@impl true
def autogenerate(), do: gen()

@doc "Generates a random ULID."
@spec gen() :: t()
def gen() do
	{:ok, id} = encode(bingen())
	id
end

@doc "Generates a random ULID in binary format."
@spec bingen() :: raw()
def bingen() do
	import DateTime

	<<ts::binary-6, _::binary>> =
		utc_now() |> to_unix(:millisecond) |> :binary.encode_unsigned()
	rand = :crypto.strong_rand_bytes(10)
	ts <> rand
end

@doc "Fetch the timestamp out of an encoded or raw ULID."
@spec ts(t() | raw()) :: {:ok, DateTime.t()} | {:error, atom()}
def ts(<<x0::8, x1::8, x2::8, x3::8, x4::8, x5::8, x6::8, x7::8, x8::8, x9::8, _::binary-16>>) do
	import DateTime

	<<ts::binary-6, _::bitstring-2>> = <<
		d(x0)::5, d(x1)::5, d(x2)::5, d(x3)::5, d(x4)::5,
		d(x5)::5, d(x6)::5, d(x7)::5, d(x8)::5, d(x9)::5,
	>>
	:binary.decode_unsigned(ts) |> from_unix(:millisecond)
end
def ts(<<ts::binary-6, _::binary-10>>) do
	import DateTime

	:binary.decode_unsigned(ts) |> from_unix(:millisecond)
end
def ts(_) do
	{:error, :invalid}
end

defp encode(<<x00::5, x01::5, x02::5, x03::5, x04::5, x05::5, x06::5, x07::5,
		x08::5, x09::5, x10::5, x11::5, x12::5, x13::5, x14::5, x15::5, x16::5,
		x17::5, x18::5, x19::5, x20::5, x21::5, x22::5, x23::5, x24::5, x25::3>>) do
	import Bitwise

	{:ok, <<
		e(x00), e(x01), e(x02), e(x03), e(x04), e(x05), e(x06), e(x07), e(x08),
		e(x09), e(x10), e(x11), e(x12), e(x13), e(x14), e(x15), e(x16), e(x17),
		e(x18), e(x19), e(x20), e(x21), e(x22), e(x23), e(x24), e(bsl(x25, 2)),
	>>}
end
defp encode(_), do: :error

defp decode(<<x00::8, x01::8, x02::8, x03::8, x04::8, x05::8, x06::8, x07::8,
		x08::8, x09::8, x10::8, x11::8, x12::8, x13::8, x14::8, x15::8, x16::8,
		x17::8, x18::8, x19::8, x20::8, x21::8, x22::8, x23::8, x24::8, x25::8>>) do
	import Bitwise

	{:ok, <<
		d(x00)::5, d(x01)::5, d(x02)::5, d(x03)::5, d(x04)::5, d(x05)::5, d(x06)::5, d(x07)::5, d(x08)::5,
		d(x09)::5, d(x10)::5, d(x11)::5, d(x12)::5, d(x13)::5, d(x14)::5, d(x15)::5, d(x16)::5, d(x17)::5,
		d(x18)::5, d(x19)::5, d(x20)::5, d(x21)::5, d(x22)::5, d(x23)::5, d(x24)::5, bsr(d(x25), 2)::3,
	>>}
rescue
	ArgumentError -> :error
end
defp decode(_), do: :error

@compile {:inline, e: 1}
defp e(0),  do: ?0
defp e(1),  do: ?1
defp e(2),  do: ?2
defp e(3),  do: ?3
defp e(4),  do: ?4
defp e(5),  do: ?5
defp e(6),  do: ?6
defp e(7),  do: ?7
defp e(8),  do: ?8
defp e(9),  do: ?9
defp e(10), do: ?A
defp e(11), do: ?B
defp e(12), do: ?C
defp e(13), do: ?D
defp e(14), do: ?E
defp e(15), do: ?F
defp e(16), do: ?G
defp e(17), do: ?H
defp e(18), do: ?J
defp e(19), do: ?K
defp e(20), do: ?M
defp e(21), do: ?N
defp e(22), do: ?P
defp e(23), do: ?Q
defp e(24), do: ?R
defp e(25), do: ?S
defp e(26), do: ?T
defp e(27), do: ?V
defp e(28), do: ?W
defp e(29), do: ?X
defp e(30), do: ?Y
defp e(31), do: ?Z

@compile {:inline, d: 1}
defp d(?0), do: 0
defp d(?O), do: 0
defp d(?o), do: 0
defp d(?1), do: 1
defp d(?I), do: 1
defp d(?i), do: 1
defp d(?L), do: 1
defp d(?l), do: 1
defp d(?2), do: 2
defp d(?3), do: 3
defp d(?4), do: 4
defp d(?5), do: 5
defp d(?6), do: 6
defp d(?7), do: 7
defp d(?8), do: 8
defp d(?9), do: 9
defp d(?A), do: 10
defp d(?a), do: 10
defp d(?B), do: 11
defp d(?b), do: 11
defp d(?C), do: 12
defp d(?c), do: 12
defp d(?D), do: 13
defp d(?d), do: 13
defp d(?E), do: 14
defp d(?e), do: 14
defp d(?F), do: 15
defp d(?f), do: 15
defp d(?G), do: 16
defp d(?g), do: 16
defp d(?H), do: 17
defp d(?h), do: 17
defp d(?J), do: 18
defp d(?j), do: 18
defp d(?K), do: 19
defp d(?k), do: 19
defp d(?M), do: 20
defp d(?m), do: 20
defp d(?N), do: 21
defp d(?n), do: 21
defp d(?P), do: 22
defp d(?p), do: 22
defp d(?Q), do: 23
defp d(?q), do: 23
defp d(?R), do: 24
defp d(?r), do: 24
defp d(?S), do: 25
defp d(?s), do: 25
defp d(?T), do: 26
defp d(?t), do: 26
defp d(?V), do: 27
defp d(?v), do: 27
defp d(?W), do: 28
defp d(?w), do: 28
defp d(?X), do: 29
defp d(?x), do: 29
defp d(?Y), do: 30
defp d(?y), do: 30
defp d(?Z), do: 31
defp d(?z), do: 31
defp d(_), do: raise ArgumentError
end
