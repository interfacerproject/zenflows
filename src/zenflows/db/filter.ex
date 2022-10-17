# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.DB.Filter do
@moduledoc "Filtering helpers for Filter modules."

alias Ecto.Changeset

@type params() :: %{atom() => term()}
@type error() :: {:error, Changeset.t()}
@type result() :: {:ok, Ecto.Query.t()} | error()

def escape_like(v) do
	Regex.replace(~r/\\|%|_/, v, &"\\#{&1}")
end

@doc """
Changeset helper to check that `a` and `b` are not provided at the same time.
"""
@spec check_xor(Changeset.t(), atom(), atom()) :: Changeset.t()
def check_xor(cset, a, b) do
	x = Changeset.get_change(cset, a)
	y = Changeset.get_change(cset, b)

	if x && y do
		msg = "can't provide both"

		cset
		|> Changeset.add_error(a, msg)
		|> Changeset.add_error(b, msg)
	else
		cset
	end
end
end
