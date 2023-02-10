# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
