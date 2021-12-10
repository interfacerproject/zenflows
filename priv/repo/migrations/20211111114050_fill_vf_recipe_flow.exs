defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_recipe_flow do
use Ecto.Migration

def change() do
	alter table("vf_recipe_flow") do
		add :action, :vf_action_enum, null: false
		add :recipe_input_of_id, references("vf_recipe_process")
		add :recipe_output_of_id, references("vf_recipe_process")
		add :recipe_flow_resource_id, references("vf_recipe_resource")
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :recipe_clause_of_id, references("vf_recipe_exchange")
		add :note, :text
	end
end
end
