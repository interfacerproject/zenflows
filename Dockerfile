ARG MIX_ENV=prod
FROM elixir:1.13-alpine AS build

WORKDIR /app

ARG MIX_ENV
ENV MIX_ENV="${MIX_ENV}"

RUN mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock ./
COPY conf conf
RUN mix do deps.get, deps.compile --only "${MIX_ENV}"

COPY priv priv
COPY src src
RUN mix do compile, release


FROM alpine:3.16 AS app

ARG MIX_ENV
ENV MIX_ENV="${MIX_ENV}"

RUN apk add --no-cache libstdc++ openssl ncurses-libs

ENV USER=zenflows
ENV GROUP=zenflows
ENV GID=1000
ENV UID=1000

WORKDIR "/home/${USER}/app"

RUN addgroup -Sg"${GID}" "${GROUP}" \
	&& adduser -s/bin/sh -u"${UID}" -G"${GROUP}" -h"/home/${USER}" -D "${USER}" \
	&& su "${USER}"

USER "${USER}"

COPY --from=build --chown="${USER}":"${GROUP}" /app/_build/"${MIX_ENV}"/rel/zenflows ./

ENTRYPOINT ["bin/zenflows"]

CMD ["start"]
