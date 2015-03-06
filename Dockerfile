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
  PSQL_HISTORY=/home/rails/.psql_history

# Install base packages.
RUN apt-get update && apt-get -y install \
  curl \
  ghostscript \
  git \
  imagemagick \
  graphviz \
  mysql-client \
  nano \
  sqlite3 \
  wget

# Add postgresql client from official source.
RUN \
  cd /tmp && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  wget https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
  apt-key add ACCC4CF8.asc && \
  apt-get update && \
  apt-get -y install libpq-dev postgresql-client-9.4 postgresql-contrib-9.4

# Install nodejs from official source.
RUN \
  curl -sL https://deb.nodesource.com/setup | bash - && \
  apt-get install -y nodejs

# Install ruby gems.
RUN gem install awesome_print bundler rubygems-update --no-ri --no-rdoc

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Define working directory.
WORKDIR /usr/src/app

# Add files.
COPY entrypoint /usr/local/bin/rails-docker-entrypoint

# Define volumes.
VOLUME ["/home/rails", "/etc/rails", "/var/lib/rails", "/var/www/railsapp", "/var/log/rails", "/tmp/rails"]

# Define the entrypoint
ENTRYPOINT ["/usr/local/bin/rails-docker-entrypoint"]

# Copy the Gemfile into place and bundle.
ONBUILD ADD Gemfile /usr/src/app/Gemfile
ONBUILD ADD Gemfile.lock /usr/src/app/Gemfile.lock
ONBUILD RUN echo "gem: --no-ri --no-rdoc" > ${HOME}/.gemrc
ONBUILD RUN rm -rf .bundle && bundle install --without development test --deployment

# Copy the rest of the application into place.
ONBUILD ADD . /usr/src/app

# Dump out the git revision.
ONBUILD RUN \
  mkdir -p ./.git/objects && \
  echo "$(git rev-parse HEAD)" > ./build-info.txt && \
  rm -rf ./.git
