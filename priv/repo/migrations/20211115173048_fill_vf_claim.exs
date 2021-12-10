defmodule Zenflows.Ecto.Repo.Migrations.Fill_vf_claim do
use Ecto.Migration

def change() do
	alter table("vf_claim") do
		add :action, :vf_action_enum, null: false
		add :receiver_id, references("vf_agent"), null: false
		add :provider_id, references("vf_agent"), null: false
		add :resource_classified_as, {:array, :text}
		add :resource_conforms_to_id, references("vf_resource_specification")
		add :resource_quantity_id, references("vf_measure")
		add :effort_quantity_id, references("vf_measure")
		add :triggered_by_id, references("vf_economic_event")
		add :due, :utc_datetime_usec
		add :created, :utc_datetime_usec
		add :finished, :boolean, default: false, null: false
		add :note, :text
		add :agreed_in, :text
		# add :in_scope_of
	end
end
end
