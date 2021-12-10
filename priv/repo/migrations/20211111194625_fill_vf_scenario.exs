defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_scenario do
use Ecto.Migration

def change() do
	alter table("vf_scenario") do
		add :name, :text, null: false
		add :has_beginning, :utc_datetime_usec
		add :has_end, :utc_datetime_usec
		# add :in_scope_of
		add :defined_as_id, references("vf_scenario_definition")
		add :refinement_of_id, references("vf_scenario")
		add :note, :text
	end
end
end
