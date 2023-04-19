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

defmodule Zenflows.Wallet do
@moduledoc """
A module to interact with Zenflows Wallet (idea and strength wallet)
"""

alias Mint
alias Zenflows.DB.ID
alias Zenflows.{HTTPC, Restroom}

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

@spec add_idea_points(ID.t(), Decimal.t()) :: :ok | :error
def add_idea_points(owner_id, amount) do
	add_points(owner_id, amount, "idea")
end

@spec add_strength_points(ID.t(), Decimal.t()) :: :ok | :error
def add_strength_points(owner_id, amount) do
	add_points(owner_id, amount, "strength")
end

@spec add_points(ID.t(), Decimal.t(), String.t()) :: :ok | :error
defp add_points(owner_id, amount, type) do
	with {:ok, post_body} <- Jason.encode(%{
				token: type,
				amount: Decimal.to_string(amount, :normal),
				owner: owner_id,
			}),
			{:ok, headers} <- signature_headers(post_body),
			{:ok, %{status: 200, data: body}} <-
				request("POST", "/token", headers, post_body),
			{:ok, %{"success" => true}} <- Jason.decode(body) do
		:ok
	else _ ->
		:error
	end
end

@spec signature_headers(String.t()) :: {:ok, Mint.Types.headers()} | {:error, term()}
defp signature_headers(data) do
	with {:ok, pubkey} <- Restroom.generate_pubkey(keyring()),
			{:ok, %{eddsa_signature: eddsa_sig}} <- Restroom.sign_graphql(keyring(), data) do
		{:ok, [
			{"did-sign", eddsa_sig},
			{"did-pk", pubkey},
		]}
	end
end

@spec get_idea_points(ID.t()) :: {:ok, Decimal.t()} | :error
def get_idea_points(owner_id) do
	get_points(owner_id, "idea")
end

@spec get_strength_points(ID.t()) :: {:ok, Decimal.t()} | :error
def get_strength_points(owner_id) do
	get_points(owner_id, "strength")
end

@spec get_points(ID.t(), String.t())
	:: {:ok, Decimal.t()} | :error
def get_points(id, type) do
	with {:ok, %{status: 200, data: body}} <- request("GET", "/token/#{type}/#{id}"),
			{:ok, %{"success" => true, "amount" => amount}} <- Jason.decode(body),
			{:ok, decimal} <- Decimal.cast(amount) do
		{:ok, decimal}
	else
		_ -> :error
	end
end

@spec request(String.t(), String.t(), Mint.Types.headers(), nil | iodata())
	:: {:ok, map()} | {:error, term()}
defp request(method, path, headers \\ [], body \\ nil) do
	HTTPC.request(__MODULE__, method, path, headers, body)
end

# Return the scheme of did from the configs.
@spec scheme() :: :http | :https
defp scheme() do
	Keyword.fetch!(conf(), :wallet_uri).scheme
end

# Return the hostname of did from the configs.
@spec host() :: String.t()
defp host() do
	Keyword.fetch!(conf(), :wallet_uri).host
end

# Return the port of wallet from the configs.
@spec port() :: non_neg_integer()
defp port() do
	Keyword.fetch!(conf(), :wallet_uri).port
end

# Return the private keyring of the server from the configs.
@spec keyring() :: nil | map()
defp keyring() do
	Keyword.fetch!(conf(), :keyring)
end

# Return the application configurations of this module.
@spec conf() :: Keyword.t()
defp conf() do
	Application.fetch_env!(:zenflows, __MODULE__)
end
end
