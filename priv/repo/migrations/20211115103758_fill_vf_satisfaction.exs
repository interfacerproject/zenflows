defmodule Zenflows.DB.Repo.Migrations.Fill_vf_satisfaction do
use Ecto.Migration

def change() do
	alter table("vf_satisfaction") do
		add :satisfies_id, references("vf_intent"), null: false
		add :satisfied_by_id, references("vf_event_or_commitment"), null: false
		add :resource_quantity_has_unit_id, references("vf_unit")
		add :resource_quantity_has_numerical_value, :float
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :float
		add :note, :text
	end
end
end
