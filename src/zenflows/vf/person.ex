defmodule Zenflows.VF.Person do
@moduledoc "A natural person."

use Zenflows.DB.Schema

alias Zenflows.Restroom
alias Zenflows.VF.{SpatialThing, Validate}

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
	pubkeys: binary(),
	pubkeys_encoded: String.t() | nil,
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
	field :pubkeys, :binary
	field :pubkeys_encoded, :string, virtual: true
end

@insert_reqr ~w[name user email pass_plain pubkeys_encoded]a
@insert_cast @insert_reqr ++ ~w[image note primary_location_id]a
# TODO: Maybe add email to @update_cast as well?
@update_cast ~w[name image note primary_location_id user pass_plain]a

# insert changeset
@doc false
@spec chgset(params()) :: Changeset.t()
def chgset(params) do
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
	|> decode_pubkeys()
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.unique_constraint(:email)
	|> Changeset.assoc_constraint(:primary_location)
	|> Changeset.check_constraint(:pubkeys, name: :type_mutex)
end

# update changeset
@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema, params) do
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

# Hash the passphrase in the virtual field `:pass_plain` before saving
# to the database.  The hashed passphrase will be available as `:pass`
# thereafter.
@spec hash_pass(Changeset.t()) :: Changeset.t()
defp hash_pass(cset) do
	if plain = Changeset.get_change(cset, :pass_plain) do
		hash = Restroom.passgen(plain)
		Changeset.put_change(cset, :pass, hash)
	else
		cset
	end
end

# Validate that :email is a valid email address.
@spec check_email(Changeset.t()) :: Changeset.t()
defp check_email(cset) do
	# works good enough for now
	Changeset.validate_format(cset, :email, ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/)
end

@spec decode_pubkeys(Changeset.t()) :: Changeset.t()
defp decode_pubkeys(cset) do
	with {:ok, val} <- Changeset.fetch_change(cset, :pubkeys_encoded),
			{:ok, decoded} <- Base.url_decode64(val) do
		Changeset.put_change(cset, :pubkeys, decoded)
	else _ ->
		Changeset.add_error(cset, :pubkeys, "not valid url-safe base64-encoded string")
	end
end
end
