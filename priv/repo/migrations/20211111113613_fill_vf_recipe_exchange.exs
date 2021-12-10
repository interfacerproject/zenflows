defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_recipe_exchange do
use Ecto.Migration

def change() do
	alter table("vf_recipe_exchange") do
		add :name, :text, null: false
		add :note, :text
	end
end
end
