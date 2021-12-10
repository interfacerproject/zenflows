defmodule Zenflows.Valflow.Person do
@moduledoc "A natural person."

use Zenflows.Ecto.Schema

alias Zenflows.Crypto
alias Zenflows.Valflow.{SpatialThing, Validate}

@type t() :: %__MODULE__{
	type: :per,
	name: String.t(),
	image: String.t() | nil,
	note: String.t() | nil,
	primary_location: SpatialThing.t() | nil,
	user: String.t(),
	email: String.t(),
	pass: binary(),
	pass_plain: String.t() | nil,
}

schema "vf_agent" do
	field :type, Ecto.Enum, values: [:per], default: :per
	field :name, :string
	field :image, :string, virtual: true
	field :note, :string
	belongs_to :primary_location, SpatialThing
	field :user, :string
	field :email, :string
	field :pass, :binary, redact: true
	field :pass_plain, :string, virtual: true, redact: true
end

@insert_reqr ~w[name user email pass_plain]a
@insert_cast @insert_reqr ++ ~w[image note primary_location_id]a
# TODO: Maybe add email to @update_cast as well?
@update_cast ~w[name image note primary_location_id user pass_plain]a

# insert changeset
@doc false
@spec chset(params()) :: Changeset.t()
def chset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.name(:email)
	|> Validate.name(:pass_plain)
	|> Validate.uri(:image)
	|> Validate.note(:note)
	|> check_email()
	|> hash_pass()
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.unique_constraint(:email)
	|> Changeset.assoc_constraint(:primary_location)
end

# update changeset
@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.name(:pass_plain)
	|> Validate.uri(:image)
	|> Validate.note(:note)
	|> check_email()
	|> hash_pass()
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.assoc_constraint(:primary_location)
end

# Hash the passphrase in the virtual field :pass_plain before saving to
# the database.  The hashed passphrase will be available as :pass thereafter.
@spec hash_pass(Changeset.t()) :: Changeset.t()
defp hash_pass(cset) do
	if plain = Changeset.get_change(cset, :pass_plain) do
		hash = Crypto.gen_hash(plain)
		Changeset.put_change(cset, :pass, hash)
	else
		cset
	end
end

# Validate that :email is a valid email address.
@spec check_email(Changeset.t()) :: Changeset.t()
defp check_email(cset) do
	cset
end
end
