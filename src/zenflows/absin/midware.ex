defmodule Zenflows.Absin.Midware do
@moduledoc """
Absinthe middleware for Ecto.Changeset errors.
"""

alias Ecto.Changeset, as: Chset

@behaviour Absinthe.Middleware

@impl true
def call(res, _) do
	%{res | errors: Enum.flat_map(res.errors, &handle/1)}
end

defp handle(%Chset{} = cset) do
	cset
	|> Chset.traverse_errors(fn {err, _} -> err end)
	|> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
end

defp handle(error) do
	[error]
end
end
