defmodule Zenflows.GQL.MW.Admin do
@moduledoc """
Absinthe middleware to authenticate administrative calls.
"""

@behaviour Absinthe.Middleware

alias Zenflows.Restroom

@impl true
def call(res, _opts) do
	with %{gql_admin: key} <- res.context,
			{:ok, key_given} <- Base.decode16(key, case: :lower),
			key_want = Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key],
			true <- Restroom.byte_equal?(key_given, key_want) do
    	res
	else _ ->
		Absinthe.Resolution.put_result(res, {:error, "you are not an admin"})
	end
end
end
