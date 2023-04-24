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

defmodule Zenflows.File.Join do
@moduledoc """
Join table for Files and the tables that need files.
"""

use Zenflows.DB.Schema

require Logger

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.File
alias Zenflows.VF.{
	Agent,
	EconomicResource,
	Intent,
	RecipeResource,
	ResourceSpecification,
}

@type t() :: %__MODULE__{
	file: File.t(),
	hash: String.t(),
	name: String.t(),
	description: String.t(),
	mime_type: String.t(),
	extension: String.t(),
	recipe_resource: RecipeResource.t() | nil,
	economic_resource: EconomicResource.t() | nil,
	agent: Agent.t() | nil,
	resource_specification: ResourceSpecification.t() | nil,
	intent: Intent.t() | nil,
}

@primary_key false
@timestamps_opts type: :utc_datetime_usec, inserted_at: :inserted_at
schema "zf_file_join" do
	belongs_to :file, File, primary_key: true, type: :string,
		references: :hash, foreign_key: :hash

	belongs_to :recipe_resource, RecipeResource
	belongs_to :economic_resource, EconomicResource
	belongs_to :agent, Agent
	belongs_to :resource_specification, ResourceSpecification
	belongs_to :intent, Intent

	field :name, :string
	field :description, :string
	field :mime_type, :string
	field :extension, :string
	timestamps()
end

@reqr ~w[hash name description mime_type extension]a
@cast @reqr ++ ~w[
	recipe_resource_id economic_resource_id agent_id
	resource_specification_id intent_id
]a

@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.key(:hash)
	|> Validate.name(:name)
	|> Validate.note(:description)
	|> Validate.name(:mime_type)
	|> Validate.name(:extension)
	|> Validate.exist_xor(~w[
		recipe_resource_id economic_resource_id
		agent_id resource_specification_id intent_id
	]a)
	|> Changeset.assoc_constraint(:file)
	|> Changeset.assoc_constraint(:recipe_resource)
	|> Changeset.assoc_constraint(:economic_resource)
	|> Changeset.assoc_constraint(:agent)
	|> Changeset.assoc_constraint(:resource_specification)
	|> Changeset.assoc_constraint(:intent)
end
end
