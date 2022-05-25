defmodule Zenflows.DB.Repo.Migrations.Fill_vf_agreement do
use Ecto.Migration

def change() do
	alter table("vf_agreement") do
		add :name, :text, null: false
		add :note, :text
		add :created, :timestamptz, null: false
	end
end
end
