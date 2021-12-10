defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_recipe_process do
use Ecto.Migration

def change() do
	alter table("vf_recipe_process") do
		add :name, :text, null: false
		add :has_duration_id, references("vf_duration", on_delete: :nilify_all)
		add :process_classified_as, {:array, :text}
		add :process_conforms_to_id, references("vf_process_specification")
		add :note, :text
	end
end
end
