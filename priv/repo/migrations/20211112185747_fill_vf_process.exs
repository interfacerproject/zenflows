defmodule Zenflows.DB.Repo.Migrations.Fill_vf_process do
use Ecto.Migration

def change() do
	alter table("vf_process") do
		add :name, :text, null: false
		add :note, :text
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :finished, :bool, null: false, default: false
		add :classified_as, {:array, :text}
		add :based_on_id, references("vf_process_specification")
		add :planned_within_id, references("vf_plan")
		add :nested_in_id, references("vf_scenario")
		# :in_scope_of
	end
end
end
