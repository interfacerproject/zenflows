defmodule Zenflows.DB.Repo.Migrations.Fill_vf_product_batch do
use Ecto.Migration

def change() do
	alter table("vf_product_batch") do
		add :batch_number, :text, null: false
		add :expiry_date, :timestamptz
		add :production_date, :timestamptz
	end
end
end
