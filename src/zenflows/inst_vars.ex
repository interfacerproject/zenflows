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

defmodule Zenflows.InstVars do
@moduledoc false
# Don't use this module; it's designed to be only used within
# Zenflows.InstVars.Domain and the migration script.

use Ecto.Schema

alias Zenflows.VF.{ResourceSpecification, Unit}

@type t() :: %__MODULE__{
	unit_one: Unit,
	spec_currency: ResourceSpecification,
	spec_project_design: ResourceSpecification,
	spec_project_service: ResourceSpecification,
	spec_project_product: ResourceSpecification,
	spec_dpp: ResourceSpecification,
	spec_machine: ResourceSpecification,
	spec_material: ResourceSpecification,
}

@primary_key false
@foreign_key_type Zenflows.DB.ID
schema "zf_inst_vars" do
	belongs_to :unit_one, Unit
	belongs_to :spec_currency, ResourceSpecification
	belongs_to :spec_project_design, ResourceSpecification
	belongs_to :spec_project_service, ResourceSpecification
	belongs_to :spec_project_product, ResourceSpecification
	belongs_to :spec_dpp, ResourceSpecification
	belongs_to :spec_machine, ResourceSpecification
	belongs_to :spec_material, ResourceSpecification
end
end
