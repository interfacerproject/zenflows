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

defmodule Zenflows.Keypairoom.Resolv do
@moduledoc "Resolvers of keypairoom-related queries."

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}

require Logger

alias Zenflows.Keypairoom.Domain
def keypairoom_server(%{first_registration: first?, user_data: data}, _) do
	with {:ok, %{email: email}} <- parse_keypairoom_server(data) do
		Domain.keypairoom_server(first?, email, data)
	end
end

@spec parse_keypairoom_server(Schema.params())
	:: {:ok, map()} | {:error, Changeset.t()}
defp parse_keypairoom_server(params) do
	{%{}, %{email: :string}}
	|> Changeset.cast(params, [:email])
	|> Changeset.validate_required(:email)
	|> Validate.email(:email)
	|> Changeset.apply_action(nil)
end
end
