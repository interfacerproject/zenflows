defmodule Zenflows.SQL.Repo.Migrations.Fill_vf_spatial_thing do
use Ecto.Migration

def change() do
	alter table("vf_spatial_thing") do
		add :name, :text, null: false
		add :note, :text
		add :mappable_address, :text
		add :lat, :float
		add :long, :float
		add :alt, :float
	end
end
end
