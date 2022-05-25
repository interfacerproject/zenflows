defmodule Zenflows.DB.Repo.Migrations.Fill_vf_economic_resource do
use Ecto.Migration

def change() do
	alter table("vf_economic_resource") do
		add :name, :text, null: false
		add :note, :text
		# add :image
		add :tracking_identifier, :text
		add :classified_as, {:array, :text}
		add :conforms_to_id, references("vf_resource_specification"), null: false
		add :accounting_quantity_has_unit_id, references("vf_unit"), null: false
		add :accounting_quantity_has_numerical_value, :float, null: false
		add :onhand_quantity_has_unit_id, references("vf_unit"), null: false
		add :onhand_quantity_has_numerical_value, :float, nulL: false
		add :primary_accountable_id, references("vf_agent"), null: false
		add :custodian_id, references("vf_agent"), null: false
		add :stage_id, references("vf_process_specification")
		add :state_id, :vf_action_id
		add :current_location_id, references("vf_spatial_thing")
		add :lot_id, references("vf_product_batch")
		add :contained_in_id, references("vf_economic_resource")
		add :unit_of_effort_id, references("vf_unit")
	end
end
end
