defmodule Zenflows.SQL.Repo.Migrations.Fill_vf_unit do
use Ecto.Migration

def change() do
	alter table("vf_unit") do
		add :label, :text, null: false
		add :symbol, :text, null: false
	end
end
end
