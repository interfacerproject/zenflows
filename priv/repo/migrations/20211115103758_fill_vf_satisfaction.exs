defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_satisfaction do
use Ecto.Migration

def change() do
	alter table("vf_satisfaction") do
		add :satisfies_id, references("vf_intent"), null: false
		add :satisfied_by_id, references("vf_event_or_commitment"), null: false
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :note, :text
	end
end
end
