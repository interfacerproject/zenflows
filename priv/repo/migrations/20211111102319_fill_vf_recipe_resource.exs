defmodule Zenflows.DB.Repo.Migrations.Fill_vf_recipe_resource do
use Ecto.Migration

def change() do
	alter table("vf_recipe_resource") do
		add :name, :text, null: false
		add :note, :text
		add :substitutable, :boolean, default: false, null: false
		# add :image
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :unit_of_resource_id, references("vf_unit")
		add :unit_of_effort_id, references("vf_unit")
	end
end
end
