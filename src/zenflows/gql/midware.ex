defmodule Zenflows.GQL.Midware do
@moduledoc """
Absinthe middleware for Ecto.Changeset errors.
"""

alias Ecto.Changeset, as: Chgset

@behaviour Absinthe.Middleware

@impl true
def call(res, _) do
	%{res | errors: Enum.flat_map(res.errors, &handle/1)}
end

defp handle(%Chgset{} = cset) do
	cset
	|> Chgset.traverse_errors(&elem(&1, 0))
	|> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
end

defp handle(error) do
	[error]
end
end
