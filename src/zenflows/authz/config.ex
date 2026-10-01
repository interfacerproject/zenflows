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

defmodule Zenflows.Authz.Config do
@moduledoc "Runtime configuration of authorization."

@type opts() :: [enforce: boolean(), allow_unchecked: boolean()]

@doc "Current options, read from `config :zenflows, Zenflows.Authz`."
@spec opts() :: opts()
def opts() do
	conf = Application.get_env(:zenflows, Zenflows.Authz, [])
	[
		enforce: Keyword.get(conf, :enforce, true),
		allow_unchecked: Keyword.get(conf, :allow_unchecked, false),
	]
end

@doc "Raise if a permissive option is set in production."
@spec validate!(atom(), opts()) :: :ok
def validate!(env \\ Application.get_env(:zenflows, :build_env, :prod), opts \\ opts())
def validate!(:prod, opts) do
	cond do
		not Keyword.fetch!(opts, :enforce) ->
			raise "AUTHZ_ENFORCE=false is not allowed in production"
		Keyword.fetch!(opts, :allow_unchecked) ->
			raise "AUTHZ_ALLOW_UNCHECKED=true is not allowed in production"
		true -> :ok
	end
end
def validate!(_env, _opts), do: :ok

@doc "Agents whose resources anyone may claim (e.g. the LOSH import agent)."
@spec claimable_agents() :: [String.t()]
def claimable_agents() do
	Application.get_env(:zenflows, Zenflows.Authz, [])
	|> Keyword.get(:claimable_agents, [])
end

@doc "Raise unless every claimable agent id is a valid ULID."
@spec validate_claimable!([String.t()]) :: :ok
def validate_claimable!(ids) do
	case Enum.reject(ids, &(byte_size(&1) == 26 and match?({:ok, _}, Zenflows.DB.ID.cast(&1)))) do
		[] -> :ok
		bad -> raise "AUTHZ_CLAIMABLE_AGENTS contains invalid agent ids: #{Enum.join(bad, ", ")}"
	end
end
end
