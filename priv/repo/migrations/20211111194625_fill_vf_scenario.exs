defmodule Zenflows.DB.Repo.Migrations.Fill_vf_scenario do
use Ecto.Migration

def change() do
	alter table("vf_scenario") do
		add :name, :text, null: false
		add :note, :text
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :defined_as_id, references("vf_scenario_definition")
		add :refinement_of_id, references("vf_scenario")
		# :in_scope_of
	end
end
end
