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

defmodule Zenflows.DB.Repo.Migrations.Seed_material_resources do
use Ecto.Migration

alias Zenflows.InstVars
alias Zenflows.VF.{EconomicEvent, Organization}

@materials [
	"PLA",
	"ABS",
	"PETG",
	"Nylon",
	"TPU",
	"Resin",
	"Aluminium",
	"Steel",
	"Stainless Steel",
	"Copper",
	"Brass",
	"Titanium",
	"Wood",
	"Plywood",
	"MDF",
	"Bamboo",
	"Acrylic",
	"Polycarbonate",
	"HDPE",
	"Carbon Fiber",
	"Fiberglass",
	"Leather",
	"Fabric",
	"Rubber",
	"Silicone",
	"Foam",
	"Ceramic",
	"Glass",
	"Concrete",
	"Cork",
]

def up() do
	execute(fn ->
		r = repo()
		inst_vars = r.one!(InstVars)
		unit_one_id = inst_vars.unit_one_id
		spec_material_id = inst_vars.spec_material_id

		# Create a system organization to own the material resources
		{:ok, system_org} = Organization.Domain.create(%{
			name: "System Materials Repository",
			note: "System organization that holds the seeded material resources",
		})

		# Seed each material as an economic resource via a "raise" event
		Enum.each(@materials, fn material_name ->
			{:ok, _event} = EconomicEvent.Domain.create(%{
				action_id: "raise",
				provider_id: system_org.id,
				receiver_id: system_org.id,
				resource_conforms_to_id: spec_material_id,
				resource_quantity: %{
					has_numerical_value: "1",
					has_unit_id: unit_one_id,
				},
				has_point_in_time: DateTime.utc_now(),
			}, %{
				name: material_name,
				note: "Seeded material resource: #{material_name}",
			})
		end)
	end)
end

def down() do
	# Resources created via economic events cannot be easily reversed
	# This is intentional - we don't want to delete resources that may have been used
	:ok
end
end
