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

defmodule Zenflows.GQL.MW.Errors do
@moduledoc """
Absinthe middleware for errors (Ecto.Changeset-only, for now).
"""

alias Ecto.Changeset, as: Chgset

@behaviour Absinthe.Middleware

@impl true
def call(res, _) do
	%{res | errors: Enum.flat_map(res.errors, &handle/1)}
end

defp handle(%Chgset{} = cset) do
	cset
	|> Chgset.traverse_errors(&elem(&1, 0))
	|> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
end

defp handle(error) do
	[error]
end
end
