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

ARG MIX_ENV=prod


FROM elixir:1.14-alpine AS build
ARG MIX_ENV
ENV MIX_ENV=$MIX_ENV

WORKDIR /app

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
COPY conf/buildtime.exs conf/
COPY .deps deps
RUN mix deps.compile --only "$MIX_ENV"

COPY conf conf
COPY priv priv
COPY src src
RUN mix do compile, release


FROM alpine:3.17 AS app
ARG MIX_ENV
ENV MIX_ENV=$MIX_ENV

RUN apk add --no-cache libstdc++ ncurses-libs

ARG USER=zenflows GROUP=zenflows
RUN addgroup -S "$GROUP" && adduser -SG"$GROUP" "$USER"
USER "$USER"

WORKDIR /app

COPY --from=build --chown="$USER:$GROUP" /app/_build/"$MIX_ENV"/rel/zenflows ./

EXPOSE 8000

ENTRYPOINT ["bin/zenflows"]

CMD ["start"]
