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

defmodule Zenflows.File do
@moduledoc """
File representation in storage.
"""

use Zenflows.DB.Schema

require Logger

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Agent,
	EconomicResource,
	Intent,
	RecipeResource,
	ResourceSpecification,
}

@type t() :: %__MODULE__{
	hash: String.t(),
	size: pos_integer(),
	bin: String.t() | nil,
}

@primary_key {:hash, :string, []}
@timestamps_opts type: :utc_datetime_usec, inserted_at: :inserted_at
schema "zf_file" do
	field :size, :integer
	field :bin, :string
	timestamps()
end

@reqr ~w[hash size]a
@cast @reqr ++ [:bin]

@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.key(:hash)
	|> Changeset.validate_number(:size, greater_than: 0, less_than_or_equal_to: 1024 * 1024 * 25)
	|> log_size_warning()
	|> Validate.img(:bin)
end

defp log_size_warning(cset) do
	with {:ok, hash} <- Changeset.fetch_change(cset, :hash),
			{:ok, n} when n > 1024 * 1024 * 4 <- Changeset.fetch_change(cset, :size),
		do: Logger.warning("file exceeds 4MiB: #{inspect(hash)}")
	cset
end
end
