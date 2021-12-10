defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_fulfillment do
use Ecto.Migration

def change() do
	alter table("vf_fulfillment") do
		add :fulfilled_by_id, references("vf_economic_event"), null: false
		add :fulfills_id, references("vf_commitment"), null: false
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :note, :text
	end
end
end
