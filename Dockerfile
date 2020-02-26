FROM nginx:1.17.8

ENV NODEJS_MAJOR_VERSION 12

EXPOSE 80

## The "apt-get update" is intentionally added to separate RUN as we want to cache the results of this layer.
## To enforce update on next build so that newer versions are installed, move the command in the "RUN apt-get install" below
RUN apt-get update

#Node.js Installation
RUN ["/bin/bash", \
  "-c", \
  "set -o pipefail && \
  apt-get install -y curl && \
  curl -sL https://deb.nodesource.com/setup_$NODEJS_MAJOR_VERSION.x | bash - && \
  apt-get install -y nodejs" \
  ]

# Set env variable
ARG SASS_PATH='./node_modules'
WORKDIR '/app'

COPY .dist /usr/share/nginx/html/
COPY nginx/default.conf /etc/nginx/conf.d/.