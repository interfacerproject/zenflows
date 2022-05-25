defmodule Zenflows.DB.Repo.Migrations.Fill_vf_claim do
use Ecto.Migration

def change() do
	alter table("vf_claim") do
		add :action_id, :vf_action_id, null: false
		add :receiver_id, references("vf_agent"), null: false
		add :provider_id, references("vf_agent"), null: false
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :resource_quantity_has_unit_id, references("vf_unit")
		add :resource_quantity_has_numerical_value, :float
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :float
		add :triggered_by_id, references("vf_economic_event")
		add :due, :timestamptz
		add :created, :timestamptz
		add :finished, :boolean, default: false, null: false
		add :note, :text
		add :agreed_in, :text
		# add :in_scope_of
	end
end
end
