defmodule ZenflowsTest.Crypto.Pass do
use ExUnit.Case, async: true

import Zenflows.Crypto.Pass

describe "salt" do
	test "encodes and decodes values within the range `16..255` and just 0" do
		assert {0, <<>>} =
			0
			|> salt_encode()
			|> IO.iodata_to_binary()
			|> salt_decode()

		for i <- 16..255 do
			assert {^i, <<>>} =
				i
				|> salt_encode()
				|> IO.iodata_to_binary()
				|> salt_decode()
		end
	end

	test "doesn't encode values out of the range `16..255` and just 0" do
		for i <- [15, 256] do
			assert_raise FunctionClauseError, fn ->
				i
				|> salt_encode()
				|> IO.iodata_to_binary()
				|> salt_decode()
			end
		end
	end
end

describe "itertion count" do
	test "encodes and decodes values within the range `1024..1073741823` and just 1" do
		# I figured it is fair to just test the lower and upper bounds.
		iter_1     = 1
		iter_2_min = 0b0000_0100_0000_0000
		iter_2_max = 0b0011_1111_1111_1111
		iter_3_min = 0b0000_0000_0100_0000_0000_0000
		iter_3_max = 0b0111_1111_1111_1111_1111_1111
		iter_4_min = 0b0000_0000_1000_0000_0000_0000_0000_0000
		iter_4_max = 0b0011_1111_1111_1111_1111_1111_1111_1111

		for i <- [iter_1, iter_2_min, iter_2_max, iter_3_min, iter_3_max, iter_4_min, iter_4_max] do
			assert {^i, <<>>} =
				i
				|> iter_encode()
				|> IO.iodata_to_binary()
				|> iter_decode()
		end
	end

	test "doesn't encode values out of the range `1024..1073741823` and just 1" do
		# I figured it is fair to just test the lower and upper bounds.
		iter_1     = 1
		iter_2_min = 0b0000_0100_0000_0000
		iter_4_max = 0b0011_1111_1111_1111_1111_1111_1111_1111

		for i <- [iter_1 - 1, iter_1 + 1, iter_2_min - 1, iter_4_max + 1] do
			assert_raise FunctionClauseError, fn ->
				i
				|> iter_encode()
				|> IO.iodata_to_binary()
				|> iter_decode()
			end
		end
	end
end

test "hash/1 and match?/2 works together correctly" do
	pass = "hunter2"
	h = hash(pass)
	# When imported, `Zenflows.Crypto.Pass.match?/2` conflict with
	# `Kernel.match?/2`.
	assert Zenflows.Crypto.Pass.match?(pass, h)
end
end
