defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_agent_relationship do
use Ecto.Migration

def change() do
	alter table("vf_agent_relationship") do
		add :subject_id, references("vf_agent"), null: false
		add :object_id, references("vf_agent"), null: false
		add :relationship_id, references("vf_agent_relationship_role"), null: false
		# inscope_of
		add :note, :text
	end
end
end
