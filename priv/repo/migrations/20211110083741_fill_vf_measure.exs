defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_measure do
use Ecto.Migration

def change() do
	alter table("vf_measure") do
		add :has_unit_id, references("vf_unit"), null: false
		add :has_numerical_value, :float, null: false
	end
end
end
