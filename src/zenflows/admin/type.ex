defmodule Zenflows.Admin.Type do
@moduledoc """
Basic authentication implementation to create Person Agents.
"""

use Absinthe.Schema.Notation

alias Zenflows.Admin.Resolv

@admin_key "The configuration-defined key to authenticate admin calls."

object :mutation_admin do
	@desc "Create a Person Agent, a user."
	field :create_user, non_null(:person) do
		@desc @admin_key
		arg :admin_key, non_null(:string)

		@desc "A valid email address of the user.  Must be unique."
		arg :email, non_null(:string)

		@desc "The username of the user.  Must be unique"
		arg :user, non_null(:string)

		@desc "The full name/just a label of the user.  Isn't unique."
		arg :name, non_null(:string)

		@desc "A JSON object encoded using a URL-safe, Base64 encoding."
		arg :pubkeys_encoded, non_null(:string), name: "pubkeys"

		resolve &Resolv.create_user/2
	end

	@desc "Import repositories from a softwarepassport instance."
	field :import_repos, :string do
		@desc @admin_key
		arg :admin_key, non_null(:string)

		@desc "The URL where all the repository information is listed."
		arg :url, non_null(:string)

		resolve &Resolv.import_repos/2
	end
end
end
