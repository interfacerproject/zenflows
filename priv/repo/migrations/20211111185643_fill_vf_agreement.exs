defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_agreement do
use Ecto.Migration

def change() do
	alter table("vf_agreement") do
		add :name, :text, null: false
		add :created, :utc_datetime_usec, null: false
		add :note, :text
	end
end
end
