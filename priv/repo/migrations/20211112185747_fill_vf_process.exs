defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_process do
use Ecto.Migration

def change() do
	alter table("vf_process") do
		add :name, :text, null: false
		add :has_beginning, :utc_datetime_usec
		add :has_end, :utc_datetime_usec
		add :finished, :bool, default: false, null: false
		add :based_on_id, references("vf_process_specification")
		add :classified_as, {:array, :text}
		add :note, :text
		# add :in_scope_of
		add :planned_within_id, references("vf_plan")
		add :nested_in_id, references("vf_scenario")
	end
end
end
