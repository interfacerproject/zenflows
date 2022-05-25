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
