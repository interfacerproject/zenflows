defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_product_batch do
use Ecto.Migration

def change() do
	alter table("vf_product_batch") do
		add :batch_number, :text, null: false
		add :expiry_date, :utc_datetime_usec
		add :production_date, :utc_datetime_usec
	end
end
end
