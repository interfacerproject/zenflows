defmodule Zenflows.GQL.MW.Sign do
@moduledoc """
Absinthe middleware to verify GraphQL calls.
"""

@behaviour Absinthe.Middleware

@impl true
def call(res, _opts) do
	# if this is admin-related call (such as createPerson and importRepos mutations),
	# skip it (since the `middleware/3` callback in # `Zenflows.GQL.Schema` is
	# called over and over.
	if match?(%{gql_admin: _}, res.context) do
		res
	else
		with %{gql_user: user, gql_sign: sign} <- res.context do
			# TODO: fetch raw query and provide `user`, `sign`, and the raw query to restroom.
			IO.inspect(res.context, label: "should be authenticated here")
			res
		else _ ->
			Absinthe.Resolution.put_result(res, {:error, "you are not authenticated"})
		end
	end
end
end
