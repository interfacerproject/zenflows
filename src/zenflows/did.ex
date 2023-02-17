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

defmodule Zenflows.DID do
@moduledoc """
A module to interact with the did controller instances over HTTPS.
"""

alias Zenflows.HTTPC
alias Zenflows.VF.Person

def child_spec(_) do
		Supervisor.child_spec(
			{HTTPC,
				name: __MODULE__,
				scheme: scheme(),
				host: host(),
				port: port(),
			},
			id: __MODULE__)
end

# Execute a Zencode specified by `name` with JSON data `data`.
@spec exec(String.t(), map()) :: {:ok, map()} | {:error, term()}
defp exec(name, post_data) do
	Zenflows.Restroom.request(&HTTPC.request(__MODULE__, &1, &2, &3, &4),
		"/v1/ifacer/#{name}", post_data)
end

@spec did_id(Person.t()) :: String.t()
defp did_id(person) do
	"did:dyne:#{did_spec()}:#{person.eddsa_public_key}"
end

@spec get_did(Person.t()) :: {:ok, map()} | {:error, term()}
def get_did(person) do
	case HTTPC.request(__MODULE__, "GET", "/dids/#{did_id(person)}") do
		{:ok, %{status: 200, data: body}} ->
			case Jason.decode(body) do
				{:ok, data} -> {:ok, %{"created" => false, "did" => data}}
				{:error, err} -> {:error, err}
			end
		_ ->
			{:error, "DID not found"}
	end
end

@spec request_new_did(Person.t()) :: {:ok, map()} | {:error, term()}
def request_new_did(person) do
	did_request = %{
		"proof" => %{
			"type" => "EcdsaSecp256k1Signature2019",
			"proofPurpose" => "assertionMethod"
		},
		"@context" => [
			"https://www.w3.org/ns/did/v1",
			"https://w3id.org/security/suites/ed25519-2018/v1",
			"https://w3id.org/security/suites/secp256k1-2019/v1",
			"https://w3id.org/security/suites/secp256k1-2020/v1",
			"https://dyne.github.io/W3C-DID/specs/ReflowBLS12381.json",
			%{
				"description" => "https://schema.org/description",
				"identifier" => "https://schema.org/identifier"
			}
		],
		"did_spec" => did_spec(),
		"signer_did_spec" => did_signer_spec(),
		"identity" => did_identity(),
		"ifacer_id" => %{"identifier" => person.id},
		"bitcoin_public_key" => person.bitcoin_public_key,
		"ecdh_public_key" => person.ecdh_public_key,
		"eddsa_public_key" => person.eddsa_public_key,
		"ethereum_address" => person.ethereum_address,
		"reflow_public_key" => person.reflow_public_key,
		"timestamp" =>
			DateTime.utc_now() |> DateTime.to_unix(:millisecond) |> to_string
	}

	with {:ok, did} <-
		Zenflows.Restroom.exec("pubkeys-request-signed",
			Map.merge(did_request, keyring())),
		{:ok, did_signed} <- exec("pubkeys-accept.chain", did)
	do
		{:ok, %{"created" => true, "did" => did_signed}}
	end
end

@spec claim(Ecto.Repo.t(), %{person: Person.t()}) :: {:ok, map()} | {:error, term()}
def claim(_repo, %{person: person}) do
	if keyring() == nil do
		{:error, "DID Controller not configured"}
	else
		case get_did(person) do
			{:ok, did} -> {:ok, did}
			_ -> request_new_did(person)
		end
	end
end

# Return the spec of the newly created dids
@spec did_spec() :: String.t()
defp did_spec() do
	Keyword.fetch!(conf(), :did_spec)
end

# Return the spec of the signer
@spec did_signer_spec() :: String.t()
defp did_signer_spec() do
	Keyword.fetch!(conf(), :did_signer_spec)
end

# Return the identity inside the newly created dids
@spec did_identity() :: String.t()
defp did_identity() do
	Keyword.fetch!(conf(), :did_identity)
end

# Return the scheme of did from the configs.
@spec scheme() :: :http | :https
defp scheme() do
	Keyword.fetch!(conf(), :did_uri).scheme
end

# Return the hostname of did from the configs.
@spec host() :: String.t()
defp host() do
	Keyword.fetch!(conf(), :did_uri).host
end

# Return the port of did from the configs.
@spec port() :: non_neg_integer()
defp port() do
	Keyword.fetch!(conf(), :did_uri).port
end

# Return the private keyring of the server from the configs.
@spec keyring() :: nil | map()
defp keyring() do
	Keyword.fetch!(conf(), :did_keyring)
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
