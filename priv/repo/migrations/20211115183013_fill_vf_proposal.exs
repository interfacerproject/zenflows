defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_proposal do
use Ecto.Migration

def change() do
	alter table("vf_proposal") do
		add :name, :text
		add :has_beginning, :utc_datetime_usec
		add :has_end, :utc_datetime_usec
		# add :in_scope_of_id
		add :unit_based, :boolean, default: false, null: false
		timestamps(inserted_at: :created, updated_at: false)
		add :note, :text
		add :eligible_location_id, references("vf_spatial_thing")
	end
end
end
