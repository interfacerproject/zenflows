defmodule Zenflows.SQL.Repo.Migrations.Fill_vf_process_specification do
use Ecto.Migration

def change() do
	alter table("vf_process_specification") do
		add :name, :text, null: false
		add :note, :text
	end
end
end
