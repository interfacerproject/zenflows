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

defmodule Zenflows.DB.Repo.Migrations.Create_zf_object_control do
use Ecto.Migration

def change() do
	create table("zf_object_control", primary_key: false) do
		add :target_type, :string, null: false, primary_key: true
		add :target_id, :binary_id, null: false, primary_key: true
		add :controller_id, references("vf_agent"), null: false
		add :source, :string, null: false
		add :epoch, :integer, null: false, default: 0
		timestamps()
	end
	create index("zf_object_control", [:controller_id])
	create constraint("zf_object_control", :target_type_check,
		check: "target_type IN ('process', 'proposal', 'intent')")
	create constraint("zf_object_control", :source_check,
		check: "source IN ('creation', 'admin')")
end
end
