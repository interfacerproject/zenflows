defmodule Zenflows.Ecto.Schema do
@moduledoc """
Just a wrapper around Ecto.Schema to customize it.
"""

@type params() :: %{required(binary()) => term()} | %{required(atom()) => term()}
@type id() :: Zenflows.Ecto.Id.t()

defmacro __using__(opts) do
	types? = Keyword.get(opts, :types?, true)

	quote do
		use Ecto.Schema

		alias Ecto.{Changeset, Schema}

		if unquote(types?) do
			@typep params() :: Zenflows.Ecto.Schema.params()
		end

		@primary_key {:id, Zenflows.Ecto.Id, autogenerate: true}
		@foreign_key_type Zenflows.Ecto.Id
		@timestamps_opts type: :utc_datetime_usec
	end
end
end
