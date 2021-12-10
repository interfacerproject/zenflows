defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_role_behavior do
use Ecto.Migration

def change() do
	alter table("vf_role_behavior") do
		add :name, :text, null: false
		add :note, :text
	end
end
end
