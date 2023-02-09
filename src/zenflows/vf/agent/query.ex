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

defmodule Zenflows.VF.Agent.Query do
@moduledoc false

import Ecto.Query

alias Ecto.{Changeset, Queryable}
alias Zenflows.DB.{Page, Schema, Validate}
alias Zenflows.VF.Agent

@spec all(Page.t()) :: {:ok, Queryable.t()} | {:error, Changeset.t()}
def all(%{filter: nil}), do: {:ok, Agent}
def all(%{filter: params}) do
	with {:ok, filters} <- all_validate(params) do
		{:ok, Enum.reduce(filters, Agent, &all_f(&2, &1))}
	end
end

@spec all_f(Queryable.t(), {atom(), term()}) :: Queryable.t()
defp all_f(q, {:name, v}),
	do: where(q, [x], ilike(x.name, ^"%#{v}%"))

@spec all_validate(Schema.params())
	:: {:ok, Changeset.data()} | {:error, Changeset.t()}
defp all_validate(params) do
	{%{}, %{name: :string}}
	|> Changeset.cast(params, [:name])
	|> Validate.name(:name)
	|> Validate.escape_like(:name)
	|> Changeset.apply_action(nil)
end
end
