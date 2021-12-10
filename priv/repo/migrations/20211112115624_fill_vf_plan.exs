defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_plan do
use Ecto.Migration

def change() do
	alter table("vf_plan") do
		add :name, :text, null: false
		add :created, :utc_datetime_usec
		add :due, :utc_datetime_usec
		add :note, :text
		add :refinement_of_id, references("vf_scenario")
	end
end
end
