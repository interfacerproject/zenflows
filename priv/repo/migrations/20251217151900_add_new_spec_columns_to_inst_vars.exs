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

defmodule Zenflows.DB.Repo.Migrations.Add_new_spec_columns_to_inst_vars do
use Ecto.Migration

alias Zenflows.VF.ResourceSpecification

def up() do
	# First, add the columns as nullable
	alter table("zf_inst_vars") do
		add :spec_dpp_id, references("vf_resource_specification")
		add :spec_machine_id, references("vf_resource_specification")
		add :spec_material_id, references("vf_resource_specification")
	end

	flush()

	# Create the new ResourceSpecifications and update the inst_vars row
	execute(fn ->
		r = repo()

		# Get the existing unit_one_id from the inst_vars row
		[[unit_one_id]] = r.query!("SELECT unit_one_id FROM zf_inst_vars").rows

		# Create the new resource specifications
		spec_dpp = ResourceSpecification.Domain.create!(r, %{name: "DPP", default_unit_of_resource_id: unit_one_id})
		spec_machine = ResourceSpecification.Domain.create!(r, %{name: "Machine", default_unit_of_resource_id: unit_one_id})
		spec_material = ResourceSpecification.Domain.create!(r, %{name: "Material", default_unit_of_resource_id: unit_one_id})

		# Update the inst_vars row with the new spec IDs
		r.query!("UPDATE zf_inst_vars SET spec_dpp_id = $1, spec_machine_id = $2, spec_material_id = $3",
			[spec_dpp.id, spec_machine.id, spec_material.id])
	end)

	flush()

	# Now make the columns non-nullable
	alter table("zf_inst_vars") do
		modify :spec_dpp_id, references("vf_resource_specification"), null: false, from: references("vf_resource_specification")
		modify :spec_machine_id, references("vf_resource_specification"), null: false, from: references("vf_resource_specification")
		modify :spec_material_id, references("vf_resource_specification"), null: false, from: references("vf_resource_specification")
	end
end

def down() do
	alter table("zf_inst_vars") do
		remove :spec_dpp_id
		remove :spec_machine_id
		remove :spec_material_id
	end
end
end
