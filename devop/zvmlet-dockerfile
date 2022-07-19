ARG NODE_VERSION=16
# Importing node12 docker image
FROM node:$NODE_VERSION-alpine

# Add dependencies
RUN apk add git python3 make g++

# Installing restroom
RUN yarn create restroom --all restroom-mw
WORKDIR /restroom-mw

# Configure restroom
ENV HTTP_PORT=3000
ENV HTTPS_PORT=3301
ENV OPENAPI=true
ENV FILES_DIR=./contracts
ENV CHAIN_EXT=chain
ENV YML_EXT=yml

# yarn install and run
CMD yarn start
