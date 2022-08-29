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

defmodule Zenflows.File do
@moduledoc """
File representation in storage.
"""

use Zenflows.DB.Schema

require Logger

alias Zenflows.VF.{
	Agent,
	EconomicResource,
	Intent,
	RecipeResource,
	ResourceSpecification,
	Validate,
}

@type t() :: %__MODULE__{
	hash: String.t(),
	name: String.t(),
	description: String.t(),
	mime_type: String.t(),
	extension: String.t(),
	size: pos_integer(),
	signature: String.t(),
	width: pos_integer() | nil,
	height: pos_integer() | nil,
	bin: String.t() | nil,
	recipe_resource: RecipeResource.t() | nil,
	economic_resource: EconomicResource.t() | nil,
	agent: Agent.t() | nil,
	resource_specification: ResourceSpecification.t() | nil,
	intent: Intent.t() | nil,
}

schema "zf_file" do
	field :hash, :string
	field :name, :string
	field :description, :string
	field :mime_type, :string
	field :extension, :string
	field :size, :integer
	field :signature, :string
	field :width, :integer
	field :height, :integer
	field :bin, :string
	timestamps()

	belongs_to :recipe_resource, RecipeResource
	belongs_to :economic_resource, EconomicResource
	belongs_to :agent, Agent
	belongs_to :resource_specification, ResourceSpecification
	belongs_to :intent, Intent
end

@reqr ~w[hash name description mime_type extension size signature]a
@cast @reqr ++ ~w[
	width height bin
	recipe_resource_id economic_resource_id agent_id
	resource_specification_id intent_id
]a

@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.key(:hash)
	|> Validate.name(:name)
	|> Validate.note(:description)
	|> Validate.name(:mime_type)
	|> Validate.name(:extension)
	|> Changeset.validate_number(:size, greater_than: 0, less_than_or_equal_to: 1024 * 1024 * 25)
	|> log_size_warning()
	|> Validate.key(:signature)
	|> Changeset.validate_number(:width, greater_than: 0)
	|> Changeset.validate_number(:height, greater_than: 0)
	|> Validate.img(:bin)
	|> Changeset.assoc_constraint(:recipe_resource)
	|> Changeset.assoc_constraint(:economic_resource)
	|> Changeset.assoc_constraint(:agent)
	|> Changeset.assoc_constraint(:resource_specification)
	|> Changeset.assoc_constraint(:intent)
	|> Changeset.unique_constraint(:hash)
	|> Changeset.check_constraint(:general, name: :mutex, message: """
	one of RecipeResource, EconomicResource, Agent, ResourceSpecification, or Intent must be provided.
	""")
end

defp log_size_warning(cset) do
	with {:ok, hash} <- Changeset.fetch_change(cset, :hash),
			{:ok, n} when n > 1024 * 1024 * 4 <- Changeset.fetch_change(cset, :size),
		do: Logger.warning("file exceeds 4MiB: #{inspect(hash)}")
	cset
end
end
