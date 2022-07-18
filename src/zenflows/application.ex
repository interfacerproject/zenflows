defmodule Zenflows.Application do
@moduledoc false
use Application

@impl true
def start(_type, _args) do
	print_header()

	children = [
		Zenflows.DB.Repo,
		{Plug.Cowboy, scheme: :http, plug: Zenflows.Web.Router, options: [port: 8000]},
	]

	opts = [strategy: :one_for_one, name: Zenflows.Supervisor]
	Supervisor.start_link(children, opts)
end

defp print_header() do
	unless System.get_env("NOHEADER") do
		IO.puts("""
		Zenflows is designed to implement the Valueflows vocabulary,
		written and maintained by srfsh <info@dyne.org>.
		Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.

		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU Affero General Public License as published by
		the Free Software Foundation, either version 3 of the License, or
		(at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU Affero General Public License for more details.

		You should have received a copy of the GNU Affero General Public License
		along with this program.  If not, see <https://www.gnu.org/licenses/>.
		""")
	end
end
end
