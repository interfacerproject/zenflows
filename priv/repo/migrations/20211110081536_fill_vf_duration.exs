defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_duration do
use Ecto.Migration

def change() do
	alter table("vf_duration") do
		add :unit_type, :vf_time_unit_enum, null: false
		add :numeric_duration, :float, null: false
	end

	#create constraint("vf_duration", :value_must_be_non_neg, check: "value >= 0")
end
end
