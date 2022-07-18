defmodule Zenflows.GQL.MW.Sign do
@moduledoc """
Absinthe middleware to verify GraphQL calls.
"""

@behaviour Absinthe.Middleware

alias Zenflows.Restroom
alias Zenflows.VF.Person

@impl true
def call(res, _opts) do
	# if this is admin-related call (such as createPerson and importRepos mutations),
	# skip it (since the `middleware/3` callback in # `Zenflows.GQL.Schema` is
	# called over and over.
	if match?(%{gql_admin: _}, res.context) do
		res
	else
		with %{gql_user: user, gql_sign: sign, gql_body: body} <- res.context,
				per when not is_nil(per) <- Person.Domain.by_user(user),
				true <- Restroom.verify_graphql?(body, sign, per.pubkeys) do
			res
		else _ ->
			Absinthe.Resolution.put_result(res, {:error, "you are not authenticated"})
		end
	end
end
end
