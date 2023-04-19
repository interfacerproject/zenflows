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

defmodule Zenflows.DB.Repo.Migrations.Create_and_fill_zf_inst_vars do
use Ecto.Migration

alias Zenflows.InstVars
alias Zenflows.VF.{ResourceSpecification, Unit}

def up() do
	create table("zf_inst_vars", primary_key: false) do
		add :one_row, :boolean, default: true, primary_key: true
		add :unit_one_id, references("vf_unit"), null: false
		add :spec_currency_id, references("vf_resource_specification"), null: false
		add :spec_project_design_id, references("vf_resource_specification"), null: false
		add :spec_project_service_id, references("vf_resource_specification"), null: false
		add :spec_project_product_id, references("vf_resource_specification"), null: false
	end

	create constraint("zf_inst_vars", :one_row, check: "one_row")

	flush()

	execute(fn ->
		r = repo()
		unit_one = Unit.Domain.create!(r, %{label: "one", symbol: "#"})
		spec_currency = ResourceSpecification.Domain.create!(r, %{name: "currency", default_unit_of_resource_id: unit_one.id})
		spec_design = ResourceSpecification.Domain.create!(r, %{name: "Design", default_unit_of_resource_id: unit_one.id})
		spec_service = ResourceSpecification.Domain.create!(r, %{name: "Service", default_unit_of_resource_id: unit_one.id})
		spec_product = ResourceSpecification.Domain.create!(r, %{name: "Product", default_unit_of_resource_id: unit_one.id})

		r.insert!(%InstVars{
			unit_one_id: unit_one.id,
			spec_currency_id: spec_currency.id,
			spec_project_design_id: spec_design.id,
			spec_project_service_id: spec_service.id,
			spec_project_product_id: spec_product.id,
		})
	end)
end

def down() do
	drop table("zf_inst_vars")
end
end
