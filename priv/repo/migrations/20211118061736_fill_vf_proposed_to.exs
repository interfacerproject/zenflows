defmodule Zenflows.DB.Repo.Migrations.Fill_vf_proposed_to do
use Ecto.Migration

def change() do
	alter table("vf_proposed_to") do
		add :proposed_to_id, references("vf_agent"), null: false
		add :proposed_id, references("vf_proposal"), null: false
	end
end
end
