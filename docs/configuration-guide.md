# Configuration Guide

Zenflows is configured through basic POSIX-compliant shell scripts.  When you
run `mann env.setup`, it'll copy the example template, `conf/.example-env.sh`,
to `conf/env.sh`.  You can edit that file according to your needs.  The
available options are mentioned below.


## All available options

The options here might seem a bit much, but it is to allow flexibility.  Please
also see the [Required Options](#required-options).

* `DB_HOST`: The hostname or IP address of the database host.  The default is
  `localhost`.
* `DB_PORT`: The port number of the database host.  The default is `5432`.  It
  must be an integer between `0` and `65535`, inclusive.
* `DB_NAME`: The database name of the database host.  The default is `zenflows`
  if run in production mode; `zenflows_dev` in development mode; `zenflows_test`
  in testing mode.
* `DB_USER`: The name of the user/role of the database host.
* `DB_PASS`: The passphrane of the user/role of the database host.
* `DB_SOCK`: The Unix socket path of the database daemon.
* `DB_URI`: The URI connection string.  The syntax is
  `scheme://user:pass@host:port/dbname?key0=val0&key1=val1&keyN=valN`, where:
  1. `scheme` is any valid scheme, such as `db`, `a`, `foo` or even `http`;
  2. `user` is the name of the user/role of teh database host.
  3. `pass` is the passphrane of the user/role of the database host.
  4. `host` is the hostname or IP address of the database host.
  5. `port` is the port number of the database host.
  6. `key0=val0`, `key1=val1`, and `keyN=valN` query strings are additional,
     adapter-related options, such as `ssl=true` and `timeout=10000`.  The list
     of additional options can be viewed at the [PostgreSQL Adapter docs](
     https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html#module-connection-options).

     This option should be used if extended configuration is desired (using the
     options mention in the link above).

* `ROOM_HOST`: The hostname or IP address of the Restroom instance.
* `ROOM_PORT`: The port number of the Restroom instance. It must be an integer
  between `0` and `65535`, inclusive.
* `ROOM_SALT`: The base64-encoded salt to be used with Restroom's
  keypairoomServer call.

* `ADMIN_KEY`: A 64-octect long, lowercase-base16-encoded string used for the
  authenticating calls from the administrators.  Can be generated with
  `openssl rand -hex 64`.  It is automatically generated when you run
  `mann env.setup`.


## Required Options

Some of the options on how to connect to the database and the Restroom intance
are required, along with `ADMIN_KEY` that is used authenticating admin calls.

For the Restroom instance, you need the `ROOM_HOST`, `ROOM_PORT`, and `ROOM_SALT`
options.

About the database, there are only 2 things you need to setup: how to connect to
the database host, and what credentials to use.

To specify what credentials to use, you must set `DB_USER` and `DB_PASS`
variables accordingly.

To specify how to connect to the database host, you have 3 options:

* Setting only `DB_HOST` and `DB_PORT`.  This is the most masic one, and what
  most people will use.  You don't even need to set up any of these, as these
  have the default values of `localhost` and `5432`.
* Setting only `DB_SOCK`.  This is to allow people to use Unix sockets.
* Setting only `DB_URI`.  This is to allow people to provide additional options.
  It is basically setting `DB_HOST` and `DB_PORT` in the same variable, plus
  additional options (that is, you can't use Unix sockets with this option).
These options are mutually-exclusive and the order of precedence is `DB_URI` >
`DB_SOCK` > `DB_HOST` and `DB_PORT`.
