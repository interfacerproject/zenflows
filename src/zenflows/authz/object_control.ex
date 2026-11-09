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

defmodule Zenflows.Authz.ObjectControl do
@moduledoc """
Administrative control of a process, proposal or intent.  One row per
object; `target_id` has no foreign key (it points at three tables), so
deletes remove the row explicitly (`ObjectControl.Domain.multi_remove/4`).
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.Agent

@types ~w[process proposal intent]

@type t() :: %__MODULE__{}

@primary_key false
schema "zf_object_control" do
	field :target_type, :string, primary_key: true
	field :target_id, Zenflows.DB.ID, primary_key: true
	belongs_to :controller, Agent
	field :source, Ecto.Enum, values: [:creation, :admin]
	field :epoch, :integer, default: 0
	timestamps()
end

@spec types() :: [String.t()]
def types(), do: @types

@reqr ~w[target_type target_id controller_id source]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @reqr ++ [:epoch])
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_inclusion(:target_type, @types)
	|> Changeset.assoc_constraint(:controller)
end
end
