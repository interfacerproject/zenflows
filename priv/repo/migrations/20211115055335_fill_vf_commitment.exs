defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_commitment do
use Ecto.Migration

def change() do
	alter table("vf_commitment") do
		add :action, :vf_action_enum, null: false
		add :provider_id, references("vf_agent"), null: false
		add :receiver_id, references("vf_agent"), null: false
		add :input_of_id, references("vf_process")
		add :output_of_id, references("vf_process")
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :resource_inventoried_as_id, references("vf_economic_resource")
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :has_beginning, :utc_datetime_usec
		add :has_end, :utc_datetime_usec
		add :has_point_in_time, :utc_datetime_usec
		add :due, :utc_datetime_usec
		timestamps(inserted_at: :created, updated_at: false)
		add :finished, :boolean, default: false, null: false
		add :note, :text
		# add :in_scope_of
		add :agreed_in, :text
		add :independent_demand_of_id, references("vf_plan")
		add :at_location_id, references("vf_spatial_thing")
		add :clause_of_id, references("vf_agreement")
	end
end
end
