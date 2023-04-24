# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.MixProject do
use Mix.Project

def project() do
	[
		app: :zenflows,
		version: "0.2.0",
		elixir: "~> 1.14", # erlang/otp 24-25
		start_permanent: Mix.env() == :prod,
		config_path: "conf/buildtime.exs",
		deps: deps(),
		releases: [
			zenflows: [
				include_executables_for: [:unix],
				applications: [runtime_tools: :permanent],
			],
		],
		default_release: :zenflows,
		elixirc_paths: elixirc_paths(Mix.env()),
		test_pattern: "*.test.exs",
		warn_test_pattern: "*{.test.ex,_test.ex,_test.exs}",

		# doc
		name: "Zenflows",
		source_url: "https://github.com/dyne/zenflows.git",
		hompage_url: "https://github.com/dyne/zenflows",
		docs: docs(),
	]
end

def application() do
	[
		extra_applications: [:logger, :inets, :ssl],
		mod: {Zenflows.Application, []},
	]
end

defp deps() do
	[
		# db
		{:ecto_sql, "~> 3.9"},
		{:postgrex, ">= 0.0.0"},
		{:decimal, "~> 2.0"},

		# crypto
		{:plug_crypto, "~> 1.2"},

		# http
		{:plug_cowboy, "~> 2.6"},
		{:mint, "~> 1.4"},
		{:castore, "~> 0.1"},

		# graphql
		{:absinthe, "~> 1.7"},
		{:absinthe_plug, "~> 1.5"},
		{:jason, "~> 1.4"},

		# live reload
		{:exsync, "~> 0.2", only: :dev},

		# static analysis
		{:credo, "~> 1.5", only: [:dev, :test], runtime: false},
		{:dialyxir, "~> 1.0", only: [:dev], runtime: false},

		# doc
		{:ex_doc, "~> 0.29", only: :dev, runtime: false},
	]
end

defp docs() do
[
	main: "readme",
	source_ref: "master",
	extra_section: "DOCS",
	extras: [
		"README.md",
		"docs/configuration-guide.md",
		"docs/vf-intro-gql-iface.md",
		"docs/software-licences.md",
		"docs/dependency-management.md",
		"docs/style-guide.md",
		"docs/user-creation-flow.md",
		"LICENSE",
		"CONTRIBUTING.md",
	],
	output: ".docs"
]
end

defp elixirc_paths(:test), do: ["src/", "test/help/"]
defp elixirc_paths(_),     do: ["src/"]
end
