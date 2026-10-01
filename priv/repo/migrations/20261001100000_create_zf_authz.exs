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

defmodule Zenflows.DB.Repo.Migrations.Create_zf_authz do
use Ecto.Migration

alias Zenflows.DB.ID

def up() do
	create table("zf_resource_control", primary_key: false) do
		add :resource_id, references("vf_economic_resource", on_delete: :delete_all),
			primary_key: true
		add :controller_id, references("vf_agent"), null: false
		add :source, :string, null: false
		add :epoch, :integer, null: false, default: 0
		timestamps()
	end
	create index("zf_resource_control", [:controller_id])
	create constraint("zf_resource_control", :source_check,
		check: "source IN ('creation', 'backfill', 'transfer', 'admin')")

	create table("zf_permission_log") do
		add :actor_id, :binary_id
		add :service, :string, null: false
		add :action, :string, null: false
		add :target_type, :string, null: false
		add :target_id, :binary_id, null: false
		add :subject_id, :binary_id
		add :role_key, :string
		add :before, :map
		add :after, :map
		add :request_id, :string
		add :reason, :text
		add :inserted_at, :timestamptz, null: false, default: fragment("now()")
	end
	create index("zf_permission_log", [:target_type, :target_id])
	create index("zf_permission_log", [:subject_id])

	execute """
	CREATE FUNCTION zf_permission_log_append_only() RETURNS trigger
	LANGUAGE plpgsql AS $$
	BEGIN
		RAISE EXCEPTION 'zf_permission_log is append-only';
	END
	$$
	"""
	execute """
	CREATE TRIGGER zf_permission_log_append_only
	BEFORE UPDATE OR DELETE ON zf_permission_log
	FOR EACH ROW EXECUTE PROCEDURE zf_permission_log_append_only()
	"""

	alter table("vf_agent_relationship_role") do
		add :system_key, :string
	end
	create unique_index("vf_agent_relationship_role", [:system_key])

	alter table("vf_agent_relationship") do
		add :in_scope_of_id, references("vf_agent")
		add :revoked_at, :timestamptz
	end
	create index("vf_agent_relationship", [:object_id, :relationship_id],
		where: "revoked_at IS NULL")

	flush()

	execute(fn ->
		r = repo()
		now = DateTime.utc_now()
		for {key, label, inverse} <- [
			{"org.admin", "admin", "has admin"},
			{"org.member", "member", "has member"},
		] do
			{:ok, id} = ID.dump(ID.gen())
			r.query!("""
				INSERT INTO vf_agent_relationship_role
					(id, role_label, inverse_role_label, system_key, updated_at)
				VALUES ($1, $2, $3, $4, $5)
				""", [id, label, inverse, key, now])
		end
	end)
end

def down() do
	execute "DELETE FROM vf_agent_relationship WHERE relationship_id IN (SELECT id FROM vf_agent_relationship_role WHERE system_key IS NOT NULL)"
	execute "DELETE FROM vf_agent_relationship_role WHERE system_key IS NOT NULL"
	alter table("vf_agent_relationship") do
		remove :in_scope_of_id
		remove :revoked_at
	end
	alter table("vf_agent_relationship_role") do
		remove :system_key
	end
	execute "DROP TABLE zf_permission_log"
	execute "DROP FUNCTION zf_permission_log_append_only()"
	drop table("zf_resource_control")
end
end
