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

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_economic_resource do
use Ecto.Migration

def change() do
	alter table("vf_economic_resource") do
		add :name, :text, null: false
		add :note, :text
		add :tracking_identifier, :text
		add :classified_as, {:array, :text}
		add :conforms_to_id, references("vf_resource_specification"), null: false
		add :accounting_quantity_has_unit_id, references("vf_unit"), null: false
		add :accounting_quantity_has_numerical_value, :float, null: false
		add :onhand_quantity_has_unit_id, references("vf_unit"), null: false
		add :onhand_quantity_has_numerical_value, :float, nulL: false
		add :primary_accountable_id, references("vf_agent"), null: false
		add :custodian_id, references("vf_agent"), null: false
		add :stage_id, references("vf_process_specification")
		add :state_id, :vf_action_id
		add :current_location_id, references("vf_spatial_thing")
		add :lot_id, references("vf_product_batch")
		add :contained_in_id, references("vf_economic_resource")
		add :unit_of_effort_id, references("vf_unit")
		timestamps()
	end
end
end
