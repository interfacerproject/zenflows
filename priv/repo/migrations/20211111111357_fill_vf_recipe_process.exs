defmodule Zenflows.DB.Repo.Migrations.Fill_vf_recipe_process do
use Ecto.Migration

@check """
(has_duration_unit_type IS NULL AND has_duration_numeric_duration IS NULL)
OR
(has_duration_unit_type IS NOT NULL AND has_duration_numeric_duration IS NOT NULL)
"""

def change() do
	alter table("vf_recipe_process") do
		add :name, :text, null: false
		add :note, :text
		add :process_conforms_to_id, references("vf_process_specification"), null: false
		add :process_classified_as, {:array, :text}
		add :has_duration_unit_type, :vf_time_unit
		add :has_duration_numeric_duration, :float
	end

	create constraint("vf_recipe_process", :has_duration, check: @check)
end
end
