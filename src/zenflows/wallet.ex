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
A module to interact with Zenflows Wallet (idea and strengths wallet)
"""

alias Zenflows.HTTPC
alias Zenflows.DB.ID

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

def signature_headers(data) do
	data = %{gql: "#{Base.encode64(data)}"}
	with {:ok, %{
				"eddsa_public_key" => eddsa_public_key,
				"eddsa_signature" => eddsa_signature,
			}} <- Zenflows.Restroom.exec("sign_graphql",
				Map.merge(data, keyring())) do
		{:ok, [
			{"did-sign", eddsa_signature},
			{"did-pk", eddsa_public_key},
		]}
	end
end

@spec add_points(Decimal.t(), ID.t(), atom()) :: {:ok, map()} | {:error, term()}
def add_points(amount, id, token) do
	with {:ok, request} <- Jason.encode(%{
				token: Atom.to_string(token),
				amount: amount,
				owner: id
			}),
			{:ok, headers} <- signature_headers(request),
			{:ok, %{status: 200, data: body}} <-
				HTTPC.request(__MODULE__, "POST", "/token", headers, request),
			{:ok, %{"success" => true}} <- Jason.decode(body) do
		{:ok}
	else
		_ ->
			{:error, "Could update point balance"}
	end
end

@spec get_points_amount(ID.t(), atom()) :: {:ok, map()} | {:error, term()}
def get_points_amount(id, token) do
	url = "/token/#{Atom.to_string(token)}/#{id}"
	with {:ok, %{status: 200, data: body}} <- HTTPC.request(__MODULE__, "GET", url),
			{:ok, %{"success" => true, "amount" => amount}} <- Jason.decode(body) do
		{:ok, amount}
	else
		_ ->
			{:error, "Could not fetch balance"}
	end
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
