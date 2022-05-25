defmodule Zenflows.DB.Repo.Migrations.Fill_vf_plan do
use Ecto.Migration

def change() do
	alter table("vf_plan") do
		add :name, :text, null: false
		add :note, :text
		add :created, :timestamptz
		add :due, :timestamptz
		add :refinement_of_id, references("vf_scenario")
	end
end
end
