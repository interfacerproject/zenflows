defmodule Zenflows.DB.Repo.Migrations.Fill_vf_recipe_flow do
use Ecto.Migration

@resqty_check """
(resource_quantity_has_unit_id IS NOT NULL AND resource_quantity_has_numerical_value IS NOT NULL)
OR
(resource_quantity_has_unit_id IS NULL AND resource_quantity_has_numerical_value IS NULL)
"""
@effqty_check """
(effort_quantity_has_unit_id IS NOT NULL AND effort_quantity_has_numerical_value IS NOT NULL)
OR
(effort_quantity_has_unit_id IS NULL AND effort_quantity_has_numerical_value IS NULL)
"""
@mutex_check """
(resource_quantity_has_unit_id IS NOT NULL AND resource_quantity_has_numerical_value IS NOT NULL)
OR
(effort_quantity_has_unit_id IS NOT NULL AND effort_quantity_has_numerical_value IS NOT NULL)
"""

def change() do
	alter table("vf_recipe_flow") do
		add :note, :text
		add :action_id, :vf_action_id, null: false
		add :recipe_input_of_id, references("vf_recipe_process")
		add :recipe_output_of_id, references("vf_recipe_process")
		add :recipe_clause_of_id, references("vf_recipe_exchange")
		add :recipe_flow_resource_id, references("vf_recipe_resource"), null: false
		add :resource_quantity_has_unit_id, references("vf_unit")
		add :resource_quantity_has_numerical_value, :float
		add :effort_quantity_has_unit_id, references("vf_unit")
		add :effort_quantity_has_numerical_value, :float
	end

	create constraint("vf_recipe_flow", :resource_quantity_check, check: @resqty_check)
	create constraint("vf_recipe_flow", :effort_quantity_check, check: @effqty_check)
	create constraint("vf_recipe_flow", :measure_mutex, check: @mutex_check)
end
end
