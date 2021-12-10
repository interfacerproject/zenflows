defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_appreciation do
use Ecto.Migration

def change() do
	alter table("vf_appreciation") do
		add :appreciation_of_id, references("vf_economic_event"), null: false
		add :appreciation_with_id, references("vf_economic_event"), null: false
		add :note, :text
	end
end
end
