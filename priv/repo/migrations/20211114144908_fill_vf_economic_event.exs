# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.Ecto.DB.Migrations.Fill_vf_economic_event do
use Ecto.Migration

def change() do
	alter table("vf_economic_event") do
		add :action_id, :vf_action_id, null: false
		add :input_of_id, references("vf_process")
		add :output_of_id, references("vf_process")
		add :provider_id, references("vf_agent"), null: false
		add :receiver_id, references("vf_agent"), null: false
		add :resource_inventoried_as_id, references("vf_economic_resource")
		add :to_resource_inventoried_as_id, references("vf_economic_resource")
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :resource_quantity_has_unit_id, references("vf_unit")
		add :resource_quantity_has_numerical_value, :decimal
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :decimal
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :has_point_in_time, :timestamptz
		add :note, :text
		add :to_location_id, references("vf_spatial_thing")
		add :at_location_id, references("vf_spatial_thing")
		add :realization_of_id, references("vf_agreement")
		add :triggered_by_id, references("vf_economic_event")
		add :previous_event_id, references("vf_economic_event")
		# add :in_scope_of
		add :agreed_in, :text
		timestamps()
	end
end
end
