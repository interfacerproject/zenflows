# Running a local instance

Simple instructions to run a local instance using postgres DB inside Docker and local elixir 1.12


Setup the DB
```
docker run -d -v /var/lib/postgres/data -p 5432:5432 --name db -e POSTGRES_PASSWORD=zenflows postgres:12-alpine
```

Install elixir
```
apt-get install -y erlang erlang-dev erlang-os-mon erlang-parsetools erlang-tools
```

Build Zenflows
```
mix deps.get
mix compile
```

Setup the DB for tests
```
echo << EOF > conf/test.local.exs
import Config

config :zenflows, Zenflows.DB.Repo,
        username: "postgres",
        password: "zenflows"
EOF

./mann -t db.create
./mann -t db.migrate
```

Run all tests
```
mix test
```

Clean the build
```
rm -rf ./deps
rm -rf ./_build
```

