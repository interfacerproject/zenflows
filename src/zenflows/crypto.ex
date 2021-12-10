defmodule Zenflows.Crypto do
@moduledoc "General cryptograph functionality."
# Currently containing only passphrase hasing.  Maybe I should put the
# related functionalities in submodules such as Zenflows.Crypto.Pass?

alias Plug.Crypto
alias Plug.Crypto.KeyGenerator, as: Keygen

@spec gen_hash(String.t()) :: binary()
def gen_hash(plain) do
	Keygen.generate(plain, hash_opts()[:salt], hash_opts())
end

@spec cmp_hash(binary(), binary()) :: boolean()
def cmp_hash(a, b) do
	Crypto.secure_compare(a, b)
end

@spec hash_opts() :: Keyword.t()
defp hash_opts() do
	opts()
	|> Keyword.fetch!(:hash)
	|> Keyword.take([:salt, :iterations, :length])
	|> Keyword.put(:digest, :sha512)
end

@spec opts() :: Keyword.t()
defp opts() do
	Application.fetch_env!(:zenflows, Zenflows.Crypto)
end
end
