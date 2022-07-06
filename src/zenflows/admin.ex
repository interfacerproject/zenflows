defmodule Zenflows.Admin do
@moduledoc """
Functionality to authenticate of admin-related calls.
"""

alias Zenflows.Restroom

def auth(key) do
	with {:ok, key_given} <- Base.decode16(key, case: :lower),
			key_want = Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key],
			true <- Restroom.byte_equal?(key_given, key_want) do
		:ok
	else _ ->
		{:error, "you are not authorized"}
	end
end
end
