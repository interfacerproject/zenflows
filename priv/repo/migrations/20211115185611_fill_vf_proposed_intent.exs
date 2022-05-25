defmodule Zenflows.DB.Repo.Migrations.Fill_vf_proposed_intent do
use Ecto.Migration

def change() do
	alter table("vf_proposed_intent") do
		add :reciprocal, :boolean, default: false, null: false
		add :publishes_id, references("vf_intent"), null: false
		add :published_in_id, references("vf_proposal"), null: false
	end
end
end
