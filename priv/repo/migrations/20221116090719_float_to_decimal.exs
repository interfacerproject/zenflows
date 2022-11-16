defmodule Zenflows.DB.Repo.Migrations.FloatToDecimal do
  use Ecto.Migration

  def change do
	alter table("vf_spatial_thing") do
	  modify :lat, :decimal
	  modify :long, :decimal
	  modify :alt, :decimal
	end
	alter table("vf_scenario_definition") do
	  modify :has_duration_numeric_duration, :decimal
	end
	alter table("vf_commitment") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_intent") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	  modify :available_quantity_has_numerical_value, :decimal
	end
	alter table("vf_economic_event") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_recipe_process") do
	  modify :has_duration_numeric_duration, :decimal
	end
	alter table("vf_claim") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_settlement") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_fulfillment") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_recipe_flow") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
	alter table("vf_economic_resource") do
	  modify :accounting_quantity_has_numerical_value, :decimal
	  modify :onhand_quantity_has_numerical_value, :decimal
	end
	alter table("vf_satisfaction") do
	  modify :resource_quantity_has_numerical_value, :decimal
	  modify :effort_quantity_has_numerical_value, :decimal
	end
  end
end
