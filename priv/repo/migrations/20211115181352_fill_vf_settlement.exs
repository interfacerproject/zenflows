defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_settlement do
use Ecto.Migration

def change() do
	alter table("vf_settlement") do
		add :settled_by_id, references("vf_economic_event"), null: false
		add :settles_id, references("vf_claim"), null: false
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :note, :text
	end
end
end
