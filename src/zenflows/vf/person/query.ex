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

defmodule Zenflows.VF.Person.Query do
@moduledoc false

import Ecto.Query

alias Ecto.{Changeset, Queryable}
alias Zenflows.DB.{Page, Schema, Validate}
alias Zenflows.VF.Person

@spec all(Page.t()) :: {:ok, Queryable.t()} | {:error, Changeset.t()}
def all(%{filter: nil}), do: {:ok, where(Person, type: :per)}
def all(%{filter: params}) do
	with {:ok, filters} <- all_validate(params) do
		{:ok, Enum.reduce(filters, where(Person, type: :per), &all_f(&2, &1))}
	end
end

@spec all_f(Queryable.t(), {atom(), term()}) :: Queryable.t()
defp all_f(q, {:name, v}),
	do: where(q, [x], ilike(x.name, ^"%#{v}%"))
defp all_f(q, {:user, v}),
	do: where(q, [x], ilike(x.user, ^"%#{v}%"))
defp all_f(q, {:user_or_name, v}),
	do: where(q, [x], ilike(x.user, ^"%#{v}") or ilike(x.name, ^"%#{v}"))

@spec all_validate(Schema.params()) ::
	{:ok, Changeset.data()} | {:error, Changeset.t()}
defp all_validate(params) do
	{%{}, %{name: :string, user: :string, user_or_name: :string}}
	|> Changeset.cast(params, ~w[name user user_or_name]a)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.name(:user_or_name)
	|> Validate.exist_xor([:name, :user_or_name])
	|> Validate.exist_xor([:user, :user_or_name])
	|> Validate.escape_like(:name)
	|> Validate.escape_like(:user)
	|> Validate.escape_like(:user_or_name)
	|> Changeset.apply_action(nil)
end
end
