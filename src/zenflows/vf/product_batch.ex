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

defmodule Zenflows.VF.ProductBatch do
@moduledoc """
A lot or batch, defining a resource produced at the same time in the
same way.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.Validate

@type t() :: %__MODULE__{
	batch_number: String.t(),
	expiry_date: DateTime.t() | nil,
	production_date: DateTime.t() | nil,
}

schema "vf_product_batch" do
	field :batch_number, :string
	field :expiry_date, :utc_datetime_usec
	field :production_date, :utc_datetime_usec
	timestamps()
end

@reqr [:batch_number]
@cast @reqr ++ ~w[expiry_date production_date]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:batch_number)
end
end
