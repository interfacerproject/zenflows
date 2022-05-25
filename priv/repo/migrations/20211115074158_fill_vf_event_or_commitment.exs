defmodule Zenflows.DB.Repo.Migrations.Fill_vf_event_or_commitment do
use Ecto.Migration

@check """
(event_id IS NULL AND commitment_id IS NOT NULL)
OR
(event_id IS NOT NULL AND commitment_id IS NULL)
"""

def change() do
	alter table("vf_event_or_commitment") do
		add :event_id, references("vf_economic_event")
		add :commitment_id, references("vf_commitment")
	end

	create constraint("vf_event_or_commitment", :mutex, check: @check)
end
end
