<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# Software Licenses

The list of software licenses used by Zenflows.  You can view the license
details of Zenflows in [the license file](docs/LICENSE).


## Elixir and Erlang/OTP distribution

| Name       |  License              |
|------------|-----------------------|
| elixir     | [Apache-2.0][apache2] |
| erlang/otp | [Apache-2.0][apache2] |


## Library Dependencies

| Name             | License               | Only in Development? |
|------------------|-----------------------|----------------------|
| absinthe         | [Expat][expat]        |                      |
| absinthe_plug    | [Expat][expat]        |                      |
| bunt             | [Expat][expat]        | Yes                  |
| connection       | [Apache-2.0][apache2] |                      |
| cowboy           | [ISC][isc]            |                      |
| cowboy_telemetry | [Apache-2.0][apache2] |                      |
| cowlib           | [ISC][isc]            |                      |
| credo            | [Expat][expat]        | Yes                  |
| db_connection    | [Apache-2.0][apache2] |                      |
| decimal          | [Apache-2.0][apache2] |                      |
| dialyxir         | [Apache-2.0][apache2] | Yes                  |
| ecto             | [Apache-2.0][apache2] |                      |
| ecto_sql         | [Apache-2.0][apache2] |                      |
| erlex            | [Apache-2.0][apache2] |                      |
| exsync           | [BSD-3][bsd3]         | Yes                  |
| file_system      | [WTFPL][wtfpl]        | Yes                  |
| jason            | [Apache-2.0][apache2] |                      |
| mime             | [Apache-2.0][apache2] |                      |
| nimble_parsec    | [Apache-2.0][apache2] |                      |
| plug             | [Apache-2.0][apache2] |                      |
| plug_cowboy      | [Apache-2.0][apache2] |                      |
| plug_crypto      | [Apache-2.0][apache2] |                      |
| postgrex         | [Apache-2.0][apache2] |                      |
| ranch            | [ISC][isc]            |                      |
| telemetry        | [Apache-2.0][apache2] |                      |


## Database

| Name     | License                    |
|----------|----------------------------|
| postgres | [postgresql license][psql] |


## Valueflows

| Name           | License               |
|----------------|-----------------------|
|valueflows-docs | [CC BY-SA][ccbysa]    |
|valueflows-gql  | [Apache-2.0][apache2] |

[apache2]: https://www.gnu.org/licenses/license-list.en.html#apache2
[expat]: https://www.gnu.org/licenses/license-list.en.html#Expat
[isc]: https://www.gnu.org/licenses/license-list.en.html#ModifiedBSD
[bsd3]: https://www.gnu.org/licenses/license-list.en.html#ModifiedBSD
[wtfpl]: https://www.gnu.org/licenses/license-list.en.html#WTFPL
[psql]: https://www.postgresql.org/about/licence/
[ccbysa]: https://www.gnu.org/licenses/license-list.en.html#ccbysa
