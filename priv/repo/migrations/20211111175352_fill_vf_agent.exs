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

defmodule Zenflows.DB.Repo.Migrations.Fill_vf_agent do
use Ecto.Migration

@mutex_check """
(
	type = 'per'
	AND "user" IS NOT NULL
	AND email IS NOT NULL
	AND classified_as IS NULL
)
OR
(
	type = 'org'
	AND "user" IS NULL
	AND email IS NULL
	AND ecdh_public_key IS NULL
	AND eddsa_public_key IS NULL
	AND ethereum_address IS NULL
	AND reflow_public_key IS NULL
	AND schnorr_public_key IS NULL
)
"""

def change() do
	alter table("vf_agent") do
		add :type, :vf_agent_type, null: false

		# common
		add :name, :text, null: false
		# add :image
		add :note, :text
		add :primary_location_id, references("vf_spatial_thing")

		# person
		add :user, :text
		add :email, :citext
		add :ecdh_public_key, :text
		add :eddsa_public_key, :text
		add :ethereum_address, :text
		add :reflow_public_key, :text
		add :schnorr_public_key, :text

		# organization
		add :classified_as, {:array, :text}
	end

	create index("vf_agent", :type)
	create unique_index("vf_agent", :user, when: "user IS NOT NULL")
	create unique_index("vf_agent", :email, when: "email IS NOT NULL")
	create constraint("vf_agent", :type_mutex, check: @mutex_check)
end
end
