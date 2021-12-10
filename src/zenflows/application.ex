defmodule Zenflows.Application do
@moduledoc false

use Application

@impl true
def start(_type, _args) do
	children = [
		Zenflows.Ecto.Repo,
		{Plug.Cowboy, scheme: :http, plug: Zenflows.Plug, options: [port: 8000]},
	]

	opts = [strategy: :one_for_one, name: Zenflows.Supervisor]
	Supervisor.start_link(children, opts)
end
end
