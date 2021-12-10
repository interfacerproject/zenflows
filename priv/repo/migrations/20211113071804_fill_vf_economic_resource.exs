defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_economic_resource do
use Ecto.Migration

def change() do
	alter table("vf_economic_resource") do
		add :name, :text
		add :primary_accountable_id, references("vf_agent")
		add :classified_as, {:array, :text}
		add :conforms_to_id, references("vf_resource_specification"), null: false
		add :tracking_identifier, :text
		add :lot_id, references("vf_product_batch")
		# add :image
		add :accounting_quantity_id, references("vf_measure")
		add :onhand_quantity_id, references("vf_measure")
		add :current_location_id, references("vf_spatial_thing")
		add :note, :text
		add :unit_of_effort_id, references("vf_unit")
		add :stage_id, references("vf_process_specification")
		add :state, :vf_action_enum
		add :contained_in_id, references("vf_economic_resource")
	end
end
end
