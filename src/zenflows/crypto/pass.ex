defmodule Zenflows.Crypto.Pass do
@moduledoc """
Functionality for passphrase hashing.

The `hash/1` function here is designed to output a custom-formatted
binary so that it allows future expansion.  Meaning that the outputted
binary will contain information about what type of algorith is used
(the first octet), what parameters are used for that particular function
(following couple octets).

The format looks like this (`+` used for concatenation):

* output = type + params + hash
* type = one octet, representing what algorithm is used as unsiged integer
* params = if type is `@type_pbdkf2`, it will be as: iteration-count + salt-length + salt-binary

The `params` for `@type_pbkdf2` will be (all values are inclusive):
* iteration-count = an unsigned integer within the range
 `@iter_2_min..@iter_4_max`, encoded with `iter_encode/1`
* salt-length = an unsinged integer within the range
 `@salt_min..@salt_max`, encoded as an octet with `salt_encode/1`
* salt-binary = it is the `salt-length`-octet long, cryptographically
 secure random binary, generated with `gen_salt/1`

This allows future expansion, backwards-compability, and changing
the parameter values (increasing/decreasing, for example) without
effecting the old schemas.

How paraters are encoded and decoded is descriped in their doc strings.
"""

import Bitwise
import Plug.Crypto, only: [secure_compare: 2]

# @type_invalid 0
@type_pbdkf2 1
# @type_argon2id 2
# and so on (in the future maybe)...

# Min and max salt size values in octects for pbdkf2 hashing.
@salt_min 16
@salt_max 255

# Iteration counts' min and max ranges.  Each number (such as 2 in
# `@iter_2_min`) represents the number (unsigned integer) will be encoded
# in that that much octets.
#
# `@iter_1` is special though, it represents the test-only value 1,
# which is used for speeding up tests.  Otherwise, the absolute production
# minimum is `@iter_2_min`.
@iter_1     0b1000_0001
@iter_2_min 0b0000_0100_0000_0000
@iter_2_max 0b0011_1111_1111_1111
@iter_3_min 0b0000_0000_0100_0000_0000_0000
@iter_3_max 0b0111_1111_1111_1111_1111_1111
@iter_4_min 0b0000_0000_1000_0000_0000_0000_0000_0000
@iter_4_max 0b0011_1111_1111_1111_1111_1111_1111_1111

@doc """
Hashes a passphrase in plaintext string format.  Outputs a
custom-formatted binary, thus should be stored in the database as-is
and used only with `match?/2` to securely compare generated hashes.
"""
@spec hash(String.t()) :: binary()
def hash(pass) do
	conf = conf()
	iter_cnt = Keyword.fetch!(conf, :iter)
	salt_len = Keyword.fetch!(conf, :slen)
	dkey_len = Keyword.fetch!(conf, :klen)

	# As `byte_size/1` is constant-time, I don't think we'll need to
	# keep `salt_len`'s state in `encode/4` and just use:
	# `byte_size(salt)`.
	salt = gen_salt(salt_len)
	hash = hash_pbdkf2(pass, salt, iter_cnt, dkey_len)
	encode(:pbdkf2, hash, salt, iter_cnt)
end

@doc """
Generate the hash of the given string `pass` and securly compare it
against the custom-formatted binary hash `hash`.

The information of how to hash the string `pass` will be read from the
custom-formatted binary hash `hash`.
"""
@spec match?(String.t(), binary()) :: boolean()
def match?(pass, hash) do
	case decode(hash) do
		{:pbdkf2, iter, salt, hash} -> do_match?(:pbdkf2, iter, salt, hash, pass)
	end
end

@spec do_match?(:pbdkf2, non_neg_integer(), binary(), binary(), String.t()) :: boolean()
defp do_match?(:pbdkf2, iter, salt, hash, pass) do
	h = hash_pbdkf2(pass, salt, iter, byte_size(hash))
	secure_compare(h, hash)
end

@spec hash_pbdkf2(binary(), binary(), pos_integer(), pos_integer()) :: binary()
defp hash_pbdkf2(pass, salt, iter, klen) do
	opts = [iterations: iter, length: klen, digest: :sha512]
	Plug.Crypto.KeyGenerator.generate(pass, salt, opts)
end

@doc """
Generates a cryptographically-secure random binary of the given length
in octets.

The given length must be within the range `@salt_min..@salt_max`, or 0
for testing purposes.
"""
@spec gen_salt(non_neg_integer()) :: binary()
def gen_salt(0) do
	<<>>
end

def gen_salt(len) when len >= @salt_min or len <= @salt_max do
	:crypto.strong_rand_bytes(len)
end

# Encode the given hashing algorithm and its parameters into a
# custom-formatted binary.  Can be used with `decode/1` to read the
# encoded informations back.
@spec encode(:pbdkf2, binary(), binary(), non_neg_integer()) :: binary()
defp encode(:pbdkf2, hash, salt, iter_cnt) do
	type = @type_pbdkf2
	iter = iter_encode(iter_cnt)
	salt_len = salt_encode(byte_size(salt))
	IO.iodata_to_binary([type, iter, salt_len, salt, hash])
end

# Decode the given custom-formatted hash binary and strip the information
# from their boundries.  It is designed to read the output of `encode()`
# functions (currently there's only `encode/4`).
@spec decode(binary()) :: {:pbdkf2, non_neg_integer(), binary(), binary()}
defp decode(<<@type_pbdkf2, rest::binary>>) do
	{iter, rest} = iter_decode(rest)
	{salt_len, rest} = salt_decode(rest)
	<<salt::binary-size(salt_len), hash::binary>> = rest
	{:pbdkf2, iter, salt, hash}
end

# Encodes the length (unsigned integer) of a salt binary.  Use it like
# this: `salt_iodata = salt_encode(byte_size(my_salt_binary))`.
#
# It'll encode it as iodata so the `encode/4` function can use it
# efficiently.
#
# The given length must be within the `@salt_min..@salt_max` range,
# or 0 for testing purposes.
@doc false
@spec salt_encode(non_neg_integer()) :: iodata()
def salt_encode(0) do
	[0]
end

def salt_encode(v) when v >= @salt_min and v <= @salt_max do
	[v]
end

# Decodes the binary from `salt_encode/1`.  It returns the decoded length
# (unsigned integer) and the rest of the binary in a tuple.  The returned
# salt length can be used to read the actual salt binary from the returned
# rest binary like this:
#
# ```
# 	{salt_len, rest} = salt_decode(bin)
# 	<<salt_bin::binary-size(salt_len), rest>> = rest
# ```
#
# It decodes vaulues within the range `@salt_min..@salt_max`, and 0 for
# testing purposes.
@doc false
@spec salt_decode(binary()) :: {non_neg_integer(), binary()}
def salt_decode(<<0, rest::binary>>) do
	{0, rest}
end

def salt_decode(<<x, rest::binary>>) when x >= @salt_min do
	{x, rest}
end

# Encodes the iteration count (unsigned integer). Use it like this:
# `iter_iodata = iter_encode(iter_count)`.
#
# It'll encode it as iodata so the `encode/4` function can use it
# efficiently.
#
# The given length must be within the range `@iter_2_min..@iter_4_max`,
# or 1 for testing purposes.
#
# It is going to encode the lengths:
#
#	* just 1 as just one octet
#	* the range `@iter_2_min..@iter_2_max` as two octets
#	* the range `@iter_3_min..@iter_3_max` as three octets
#	* the range `@iter_4_min..@iter_4_max` as four octets
#
# How it works:
#
# We use the first bit of the first octet to determine where the given
# binary ends.
#
# If the first bit is 0, it is a 3-octet long binary and the following
# 23 bits in big-endian order gives you the decoded integer.  Such as:
# 0XXXXXXX XXXXXXXX XXXXXXXX.
#
# If the first bit is 1, the following bit will determine whether it is
# 2-octets long or 4-octet long.  (The following two paragraphs talk
# about that.)
#
# If the first two bits is 10, it will be 2-octet long.  The following
# 14 bits in big-endian order gives you the decoded integer.  Such as:
# 10XXXXXX XXXXXXXX.
#
# If the first tow bits is 11, it will be 4-octet long.  The following
# 30 bits in big-endian order gives you the decdode integer.  Such as:
# 11XXXXXX XXXXXXXX XXXXXXXX XXXXXXXX.
#
# If the first octet is exactly 10000001, it represents the integer 1.
# It is only used for testing purposes (to speed up the tests, to be
# precise).
#
# This schema is designed so that the 3-octet long binary value gets
# the most space for the actual bits, then the 4-octet long binary, then
# the 2-octet binary.  This is because the 3-octet binary will be the
# most used one, 2-octet binary will be the least used one.
#
# Just as a quick reference on the ranges of the values (the first bits
# are separated such that they are more apparent):
#
#    1: 0b10000001
# 2min: 0b10_00010000000000
# 2max: 0b10_11111111111111
# 3min: 0b0_00000000100000000000000
# 3max: 0b0_11111111111111111111111
# 4min: 0b11_000000100000000000000000000000
# 4max: 0b11_111111111111111111111111111111
@doc false
@spec iter_encode(pos_integer()) :: iodata()
def iter_encode(1) do
	[@iter_1]
end

def iter_encode(v) when v >= @iter_2_min and v <= @iter_2_max do
	<<bor(bsr(v, 8), 0b1000_0000), v>>
end

def iter_encode(v) when v >= @iter_3_min and v <= @iter_3_max do
	b0 = bsr(v, 16)
	b1 = bsr(v, 8)
	b2 = v
	<<b0, b1, b2>>
end

def iter_encode(v) when v >= @iter_4_min and v <= @iter_4_max do
	b0 = bor(bsr(v, 24), 0b1100_0000)
	b1 = bsr(v, 16)
	b2 = bsr(v, 8)
	b3 = v
	<<b0, b1, b2, b3>>
end

# Decodes the binary from `iter_encode/1`.  It returns the decoded
# iteration count (unsigned integer) and the rest of the binary in
# a tuple.
#
# Use it like this: `{iter_cnt, rest} = iter_decode(bin)`
#
# Depending on the first octet, it determines whether if the iteration
# count is 1-, 2-, 3-, or 4-octet long.
#
# The algorithm is explained in `iter_encode/1`.
@doc false
@spec iter_decode(binary()) :: {pos_integer(), binary()}
def iter_decode(<<@iter_1, rest::binary>>) do
	{1, rest}
end

def iter_decode(<<b0, rest::binary>>) when band(b0, 0b1100_0000) == 0b1000_0000 and b0 >= 0b1000_0100 do
	<<b1, rest::binary>> = rest
	v = bor(b1, bsl(band(b0, 0b0011_1111), 8))
	{v, rest}
end

def iter_decode(<<b0, rest::binary>>) when band(b0, 0b1000_0000) == 0b0000_0000 do
	<<b1, b2, rest::binary>> = rest
	v = bor(bor(b2, bsl(b1, 8)), bsl(b0, 16))
	{v, rest}
end

def iter_decode(<<b0, rest::binary>>) when band(b0, 0b1100_0000) == 0b1100_0000 do
	<<b1, b2, b3, rest::binary>> = rest
	v = bor(bor(bor(b3, bsl(b2, 8)), bsl(b1, 16)), bsl(band(b0, 0b0011_1111), 24))
	{v, rest}
end

# Returns the configs of this particular module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
