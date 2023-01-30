# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_process do
use Ecto.Migration

def change() do
	alter table("vf_process") do
		add :name, :text, null: false
		add :note, :text
		add :has_beginning, :timestamptz
		add :has_end, :timestamptz
		add :finished, :bool, null: false, default: false
		add :classified_as, {:array, :text}
		add :based_on_id, references("vf_process_specification")
		add :planned_within_id, references("vf_plan")
		add :nested_in_id, references("vf_scenario")
		add :grouped_in_id, references("zf_process_group")
		# :in_scope_of
		timestamps()
	end
end
end
