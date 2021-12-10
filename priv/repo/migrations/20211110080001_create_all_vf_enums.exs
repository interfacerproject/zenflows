defmodule Zenflows.Ecto.Repo.Migrations.Create_vf_enums do
# New enums can be added on top of these as anoter migration files.
# The point of this migration is to just prevent circular references.

use Ecto.Migration

@time_unit_enum_up """
CREATE TYPE vf_time_unit_enum AS ENUM (
	'year',
	'month',
	'week',
	'day',
	'hour',
	'minute',
	'second'
)
"""
@time_unit_enum_down """
DROP TYPE vf_time_unit_enum
"""

@action_enum_up """
CREATE TYPE vf_action_enum AS ENUM (
	'produce',
	'use',
	'consume',
	'cite',
	'work',
	'pickup',
	'dropoff',
	'accept',
	'modify',
	'pack',
	'unpack',
	'transfer_all_rights',
	'transfer_custody',
	'transfer',
	'move',
	'raise',
	'lower'
)
"""
@action_enum_down """
DROP TYPE vf_action_enum
"""

@agent_enum_up """
CREATE TYPE vf_agent_enum AS ENUM (
	'per',
	'org'
)
"""
@agent_enum_down """
DROP TYPE vf_agent_enum
"""

def change() do
	execute @time_unit_enum_up, @time_unit_enum_down
	execute @action_enum_up, @action_enum_down
	execute @agent_enum_up, @agent_enum_down
end
end
