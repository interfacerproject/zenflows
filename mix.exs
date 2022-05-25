defmodule Zenflows.MixProject do
use Mix.Project

def project() do
	[
		app: :zenflows,
		version: "0.1.0",
		elixir: "~> 1.11", # erlang/otp 22-24
		start_permanent: Mix.env() == :prod,
		config_path: "conf/common.exs",
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
	]
end

def application() do
	[
		extra_applications: [:logger],
		mod: {Zenflows.Application, []},
	]
end

defp deps() do
	[
		# db
		{:ecto_sql, "~> 3.7"},
		{:postgrex, ">= 0.0.0"},

		# crypto
		{:plug_crypto, "~> 1.2"},

		# http
		{:plug_cowboy, "~> 2.5"},

		# graphql
		{:absinthe, "~> 1.6"},
		{:absinthe_plug, "~> 1.5"},
		{:jason, "~> 1.3"},

		# live reload
		{:exsync, "~> 0.2", only: :dev},

		# static analysis
		{:credo, "~> 1.5", only: [:dev, :test], runtime: false},
		{:dialyxir, "~> 1.0", only: [:dev], runtime: false},
	]
end

defp elixirc_paths(:test), do: ["src/", "test/help/"]
defp elixirc_paths(_),     do: ["src/"]
end
