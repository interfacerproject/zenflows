defmodule Zenflows.VF.Agent do
@moduledoc """
A person or group or organization with economic agency.
"""

use Zenflows.DB.Schema, types?: false

alias Zenflows.VF.SpatialThing

@type t() :: %__MODULE__{
	# common
	type: :per | :org, # Person or Organization
	name: String.t(),
	note: String.t() | nil,
	image: String.t() | nil,
	primary_location: SpatialThing.t() | nil,

	# person
	user: String.t() | nil,
	email: String.t() | nil,
	pass: binary() | nil,

	# organization
	classified_as: [String.t()] | nil,
}

schema "vf_agent" do
	# common
	field :type, Ecto.Enum, values: [:per, :org]
	field :name, :string
	field :note, :string
	field :image, :string, virtual: true
	belongs_to :primary_location, SpatialThing

	# person
	field :user, :string
	field :email, :string
	field :pass, :binary, redact: true

	# organization
	field :classified_as, {:array, :string}
end
end
