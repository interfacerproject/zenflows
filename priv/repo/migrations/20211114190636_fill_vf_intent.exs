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

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_intent do
use Ecto.Migration

def change() do
	alter table("vf_intent") do
		add :name, :text
		add :action_id, :vf_action_id, null: false
		add :provider_id, references("vf_agent")
		add :receiver_id, references("vf_agent")
		add :input_of_id, references("vf_process")
		add :output_of_id, references("vf_process")
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :resource_inventoried_as_id, references("vf_economic_resource")
		add :resource_quantity_has_unit_id, references("vf_unit")
		add :resource_quantity_has_numerical_value, :float
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :float
		add :available_quantity_has_unit_id, references("vf_unit")
		add :available_quantity_has_numerical_value, :float
		add :at_location_id, references("vf_spatial_thing")
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :has_point_in_time, :timestamptz
		add :due, :timestamptz
		add :finished, :boolean, default: false, null: false
		# add :image
		add :note, :text
		# add :in_scope_of
		add :agreed_in, :text
	end
end
end
