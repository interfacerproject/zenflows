# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.SQL.Repo.Migrations.Fill_zf_file do
use Ecto.Migration

@check """
num_nonnulls(
	recipe_resource_id,
	economic_resource_id,
	agent_id,
	resource_specification_id,
	intent_id
) = 1
"""

def change() do
	alter table("zf_file") do
		add :hash, :text, null: false
		add :name, :text, null: false
		add :description, :text, null: false
		add :mime_type, :text, null: false
		add :extension, :text, null: false
		add :size, :integer, null: false
		add :signature, :text, null: false
		add :width, :integer
		add :height, :integer
		add :bin, :text
		timestamps()

		add :recipe_resource_id, references("vf_recipe_resource", on_delete: :delete_all)
		add :economic_resource_id, references("vf_economic_resource", on_delete: :delete_all)
		add :agent_id, references("vf_agent", on_delete: :delete_all)
		add :resource_specification_id, references("vf_resource_specification", on_delete: :delete_all)
		add :intent_id, references("vf_intent", on_delete: :delete_all)
	end

	create unique_index("zf_file", :hash)
	create constraint("zf_file", :mutex, check: @check)
end
end
