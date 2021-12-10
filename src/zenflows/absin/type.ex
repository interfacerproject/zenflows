defmodule Zenflows.Absin.Type do
@moduledoc "Custom types or overrides for Absinthe."

use Absinthe.Schema.Notation

alias Absinthe.Blueprint.Input
alias Zenflows.Ecto.Id

@desc "A [Unified Resource Identity](https://w.wiki/4W2Y) as String."
scalar :uri, name: "URI" do
	parse &uri_parse/1
	serialize & &1
end

# TODO: Decide whether we really want these to be valid URIs or just
# Strings.
@spec uri_parse(Input.t()) :: {:ok, String.t() | nil} | :error
defp uri_parse(%Input.String{value: v}), do: {:ok, v}
defp uri_parse(%Input.Null{}), do: {:ok, nil}
defp uri_parse(_), do: :error

@spec id_parse(Input.t()) :: {:ok, Id.t() | nil} | :error
def id_parse(%Input.String{value: v}), do: Id.cast(v)
def id_parse(%Input.Null{}), do: {:ok, nil}
def id_parse(_), do: :error
end
