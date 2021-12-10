defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_resource_specification do
use Ecto.Migration

def change() do
	alter table("vf_resource_specification") do
		add :name, :text, null: false
		# add :image
		add :resource_classified_as, {:array, :text}
		add :note, :text
		add :default_unit_of_resource_id, references("vf_unit")
		add :default_unit_of_effort_id, references("vf_unit")
	end
end
end
