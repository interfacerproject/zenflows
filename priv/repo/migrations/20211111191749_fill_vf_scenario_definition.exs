defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_scenario_definition do
use Ecto.Migration

def change() do
	alter table("vf_scenario_definition") do
		add :name, :text, null: false
		add :has_duration_id, references("vf_duration")
		add :note, :text
	end
end
end
