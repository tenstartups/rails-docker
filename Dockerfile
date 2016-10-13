#
# Rails application docker image
#
# http://github.com/tenstartups/railsapp-docker
#

FROM ruby:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment.
ENV \
  DEBIAN_FRONTEND=noninteractive \
  TERM=xterm-color \
  HOME=/home/rails \
  BUNDLE_PATH=./vendor/bundle \
  BUNDLE_APP_CONFIG=./.bundle

# Install base packages.
RUN \
  apt-get update && \
  apt-get -y install \
    curl ghostscript graphicsmagick graphviz imagemagick libjpeg-turbo-progs mysql-client \
    nano net-tools nodejs optipng pdftk rsync sqlite3 wget xfonts-base xfonts-75dpi

# Add postgresql client from official source.
RUN \
  cd /tmp && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  wget https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
  apt-key add ACCC4CF8.asc && \
  apt-get update && \
  apt-get -y install libpq-dev postgresql-client-9.6 postgresql-contrib-9.6

# Install wkhtmltopdf from debian package.
RUN \
  cd /tmp && \
  wget http://download.gna.org/wkhtmltopdf/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-jessie-amd64.deb && \
  dpkg -i wkhtmltox-*.deb && \
  rm -rf wkhtmltox-*

# Define working directory.
WORKDIR ${HOME}

# Install ruby gems.
RUN \
  echo "gem: --no-document" > ${HOME}/.gemrc && \
  gem install aws-sdk bundler rake --no-document

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add files.
COPY entrypoint.rb /docker-entrypoint
COPY bundle-gems.rb /usr/local/bin/bundle-gems
COPY compile-assets.rb /usr/local/bin/compile-assets

# Define working directory.
WORKDIR /usr/src/app

# Define the entrypoint
ENTRYPOINT ["/docker-entrypoint"]

# Declare build arguments
ONBUILD ARG BUILD_REVISION=unspecified
ONBUILD ARG BUNDLE_GEMS=true
ONBUILD ARG COMPILE_ASSETS=true
ONBUILD ARG RAILS_BUILD_ENVIRONMENTS=staging,production
ONBUILD ARG CACHE_BUNDLED_GEMS=false
ONBUILD ARG CACHE_COMPILED_ASSETS=false
ONBUILD ARG AWS_ACCESS_KEY_ID
ONBUILD ARG AWS_SECRET_ACCESS_KEY
ONBUILD ARG AWS_REGION=us-east-1
ONBUILD ARG AWS_S3_BUCKET_NAME

# Copy the rest of the application into place.
ONBUILD ADD . /usr/src/app

# Execute scripts to bundle gem and compile assets
ONBUILD RUN /usr/local/bin/bundle-gems && /usr/local/bin/compile-assets

# Dump the revision argument to file if present
ONBUILD RUN echo ${BUILD_REVISION} > ./REVISION
