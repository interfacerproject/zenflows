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

defmodule Zenflows.VF.ProcessGroup do
@moduledoc """
A filesystem-like structure to hold a group of Processes.

A Process might belong to a ProcessGroup.  If that's the case, no
other ProcessGroup can belong to that particular ProcessGroup.

A ProcessGroup might belong to another ProcessGroup that is not
itself (let's call this one X).  If that's the case, no Process can
belong to X.

With above two clauses, and if we say ProcessGroup is like a Directory
and a Process is like a File in a filesystem, we basically disallow
Directories to contain nothing but either Files or other Directories.
"""

# This structure isn't part of VF, but for convince reasons, it
# was placed under the VF module.

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}

@type t() :: %__MODULE__{
	name: nil | String.t(),
	note: nil | String.t(),
	grouped_in: nil | t(),
}

schema "zf_process_group" do
	field :name, :string
	field :note, :string
	belongs_to :grouped_in, __MODULE__
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[note grouped_in_id]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.value_ne([:id, :grouped_in_id], method: :both)
	|> Changeset.assoc_constraint(:grouped_in)
end
end
