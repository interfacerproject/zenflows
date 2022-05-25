defmodule Zenflows.SQL.Repo.Migrations.Create_vf_enums do
# New enums can be added on top of these as anoter migration files.
# The point of this migration is to just prevent circular references.
use Ecto.Migration

@time_unit_up """
CREATE TYPE vf_time_unit AS ENUM (
	'year',
	'month',
	'week',
	'day',
	'hour',
	'minute',
	'second'
)
"""
@time_unit_down "DROP TYPE vf_time_unit"

@action_id_up """
CREATE TYPE vf_action_id AS ENUM (
	'produce',
	'raise',
	'consume',
	'lower',
	'use',
	'work',
	'cite',
	'deliverService',
	'pickup', 'dropoff',
	'accept', 'modify',
	'combine', 'separate',
	'transferAllRights',
	'transferCustody',
	'transfer',
	'move'
)
"""
@action_id_down "DROP TYPE vf_action_id"

@agent_type_up "CREATE TYPE vf_agent_type AS ENUM ('per', 'org')"
@agent_type_down "DROP TYPE vf_agent_type"

def change() do
	execute @time_unit_up, @time_unit_down
	execute @action_id_up, @action_id_down
	execute @agent_type_up, @agent_type_down
end
end
