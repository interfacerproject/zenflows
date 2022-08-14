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

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_proposal do
use Ecto.Migration

def change() do
	alter table("vf_proposal") do
		add :name, :text
		add :has_beginning, :utc_datetime_usec
		add :has_end, :utc_datetime_usec
		# add :in_scope_of_id
		add :unit_based, :boolean, default: false, null: false
		add :note, :text
		add :eligible_location_id, references("vf_spatial_thing")
		timestamps()
	end
end
end
