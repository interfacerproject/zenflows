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
		add :resource_quantity_has_numerical_value, :float
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :float
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :has_point_in_time, :timestamptz
		add :note, :text
		add :to_location_id, references("vf_spatial_thing")
		add :at_location_id, references("vf_spatial_thing")
		add :realization_of_id, references("vf_agreement")
		add :triggered_by_id, references("vf_economic_event")
		# add :in_scope_of
		add :agreed_in, :text
	end
end
end
