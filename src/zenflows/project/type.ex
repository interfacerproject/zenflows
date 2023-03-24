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

defmodule Zenflows.Project.Type do
@moduledoc false

alias Zenflows.Project.Resolv

use Absinthe.Schema.Notation

enum :project_type do
	value :design
	value :service
	value :product
end

input_object :project_location_params do
	field :address, non_null(:string)
	field :lat, non_null(:decimal)
	field :lng, non_null(:decimal)
end

input_object :project_license_params do
	field :scope, non_null(:string)
	field :license_id, non_null(:string)
end

input_object :project_create_params do
	# Main steps
	field :title, non_null(:string)
	field :description, non_null(:string)
	field :link, non_null(:uri)
	field :tags, list_of(non_null(:uri))

	# Linked design steps
	field :linked_design_id, :id

	# Location steps
	field :location_name, :string
	field :location, :project_location_params
	field :location_remote, :boolean

	field :images, non_null(list_of(:ifile))

	field :relations, non_null(list_of(non_null(:string)))
	field :licenses, non_null(list_of(non_null(:project_license_params)))
	field :contributors, non_null(list_of(non_null(:id)))

	field :project_type, non_null(:project_type)
end

input_object :project_add_contributor_params do
	field :contributor, :id
	field :process, :id
end

object :mutation_project do
	@desc "Flow to create a new project (economic resource with PRODUCE action)"
	field :project_create, :economic_event do
		arg :project, non_null(:project_create_params)
		resolve &Resolv.project_create/2
	end

	field :project_add_contributor, :economic_event do
		arg :contributor, non_null(:project_add_contributor_params)
		resolve &Resolv.project_add_contributor/2
	end
end
end
