defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_spatial_thing do
use Ecto.Migration

def change() do
	alter table("vf_spatial_thing") do
		add :name, :text, null: false
		add :mappable_address, :string
		add :lat, :float
		add :long, :float
		add :alt, :float
		add :note, :text
	end
end
end
