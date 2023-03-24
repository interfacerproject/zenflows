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

defmodule Zenflows.Project.Domain do
@moduledoc "Domain logic of Project flows"

alias Zenflows.DB.{Repo, Schema}
alias Zenflows.VF.{Process, SpatialThing, EconomicEvent}


@spec create_project_location(String.t(), map(), boolean(), boolean())
		:: {SpatialThing.t(), boolean()}
defp create_project_location(location_name,
		location_data, location_remote, design) do
 	remote = location_remote || design
	if location_data != nil do
		{:ok, st} = SpatialThing.Domain.create(%{
			name: location_name || location_data.address,
			addr: location_data.address,
			lat: location_data.lat || 0,
			lng: location_data.lng || 0,
		});
		{st, remote};
	else
		{nil, remote};
	end
end

@spec create(Schema.params()) :: {:ok, map()} | {:error, Changeset.t()}
def create(params) do
	inst_vars = Zenflows.InstVars.Domain.get()
	project_types = %{
		design: inst_vars.specs.spec_project_design.id,
		service: inst_vars.specs.spec_project_service.id,
		product: inst_vars.specs.spec_project_product.id
	}
	project_type = String.to_existing_atom(params.project_type)
	process_name = "creation of #{params.title} by #{params.user.name}"

	design = Map.has_key?(params, :linked_design) && String.length(params.linked_design) > 0

	tags = params.tags
	tags = if(tags != nil && length(tags)>0, do: tags, else: nil)

	{location, remote} = if Map.has_key?(params, :location)
 			|| params.location_remote do
 		create_project_location(params.location_name,
 					params.location, params.location_remote,
 					project_type == :design)
 	else
		{nil, nil}
 	end

	Repo.multi(fn ->
		with {:ok, process } <- Process.Domain.create(%{name: process_name}),
				{:ok, evt } <- EconomicEvent.Domain.create(
					%{
						action_id: "produce",
						provider_id: params.user.id,
						receiver_id: params.user.id,
						output_of_id: process.id,
						has_point_in_time: DateTime.utc_now(),
						resource_classified_as: tags,
						resource_conforms_to_id: project_types[project_type],
						resource_quantity: %{ has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id },
						to_location_id: if(location != nil, do: location.id, else: nil),
						resource_metadata: %{
							contributors: params.contributors,
							licenses: params.licenses,
							relations: params.relations,
							declarations: params.declarations,
							remote: remote,
							design: design,
						}
					},
					%{
						name: params.title,
						note: params.description,
						images: [],
						repo: params.link,
						license: if(length(params.licenses)>0, do: params.licenses[0].license_id, else: "")
					}
				) do
			# economic system: points assignments
			# addIdeaPoints(user!.ulid, IdeaPoints.OnCreate)
			# addStrengthsPoints(user!.ulid, StrengthsPoints.OnCreate)
			{:ok, evt}
		else
			{:error, message} -> {:error, message}
			_ -> {:error, "Project creation failed"}
		end
	end)
end

@spec add_contributor(Schema.params()) :: {:ok, map()} | {:error, Changeset.t()}
def add_contributor(params) do
	inst_vars = Zenflows.InstVars.Domain.get()

	Repo.multi(fn ->
		with {:ok, evt } <- EconomicEvent.Domain.create(
					%{
						action_id: "work",
						provider_id: params.contributor,
						receiver_id: params.contributor,
						input_of_id: params.process,
						has_point_in_time: DateTime.utc_now(),
						resource_conforms_to_id: inst_vars.specs.spec_project_design.id,
						effort_quantity: %{ has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id },
					}
				) do
			# economic system: points assignments
			# addIdeaPoints(user!.ulid, IdeaPoints.OnCreate)
			# addStrengthsPoints(user!.ulid, StrengthsPoints.OnCreate)
			{:ok, evt}
		else
			{:error, message} -> {:error, message}
			_ -> {:error, "Project creation failed"}
		end
	end)
end

end
