ARG MIX_ENV=prod


FROM elixir:1.13-alpine AS build
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


FROM alpine:3.16 AS app
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
