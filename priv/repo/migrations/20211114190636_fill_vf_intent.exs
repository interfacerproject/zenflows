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
