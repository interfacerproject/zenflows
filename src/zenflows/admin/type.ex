defmodule Zenflows.Admin.Type do
@moduledoc """
Basic authentication implementation to create Person Agents.
"""

use Absinthe.Schema.Notation

alias Zenflows.Admin.Resolv

object :mutation_admin do
	@desc "Create a Person Agent, a user."
	field :create_user, non_null(:person) do
		@desc "The configuration-defined key to authenticate admin calls."
		arg :admin_key, non_null(:string)

		@desc "A valid email address of the user.  Must be unique."
		arg :email, non_null(:string)

		@desc "The username of the user.  Must be unique"
		arg :user, non_null(:string)

		@desc "The plain passphrase of the user."
		arg :pass_plain, non_null(:string), name: "pass"

		@desc "The full name/just a label of the user.  Isn't unique."
		arg :name, non_null(:string)

		@desc "A JSON object encoded using a URL-safe, Base64 encoding."
		arg :pubkeys_encoded, non_null(:string), name: "pubkeys"

		resolve &Resolv.create_user/2
	end
end
end
