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

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_recipe_process do
use Ecto.Migration

@check """
(has_duration_unit_type IS NULL AND has_duration_numeric_duration IS NULL)
OR
(has_duration_unit_type IS NOT NULL AND has_duration_numeric_duration IS NOT NULL)
"""

def change() do
	alter table("vf_recipe_process") do
		add :name, :text, null: false
		add :note, :text
		add :process_conforms_to_id, references("vf_process_specification"), null: false
		add :process_classified_as, {:array, :text}
		add :has_duration_unit_type, :vf_time_unit
		add :has_duration_numeric_duration, :decimal
		timestamps()
	end

	create constraint("vf_recipe_process", :has_duration, check: @check)
end
end
