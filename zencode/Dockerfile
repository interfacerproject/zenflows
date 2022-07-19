# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

ARG NODE_VERSION=16
# Importing node12 docker image
FROM node:$NODE_VERSION-alpine

WORKDIR /app

# Add dependencies
RUN apk add git python3 make g++

# Installing restroom
RUN yarn create restroom -a .

# Configure restroom
ENV HTTP_PORT=3000
ENV HTTPS_PORT=3301
ENV OPENAPI=true
ENV FILES_DIR=./contracts
ENV CHAIN_EXT=chain
ENV YML_EXT=yml

# yarn install and run
CMD yarn start
