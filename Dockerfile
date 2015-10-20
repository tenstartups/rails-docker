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
  HOME=/home/rails

# Install base packages.
RUN apt-get update && apt-get -y install \
  curl \
  ghostscript \
  imagemagick \
  graphviz \
  libjpeg-turbo-progs \
  mysql-client \
  nano \
  optipng \
  rsync \
  sqlite3 \
  wget \
  xfonts-base \
  xfonts-75dpi

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

# Install wkhtmltopdf from debian package.
RUN \
  cd /tmp && \
  wget http://download.gna.org/wkhtmltopdf/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-jessie-amd64.deb && \
  dpkg -i wkhtmltox-*.deb && \
  rm -rf wkhtmltox-*

# Install ruby gems.
RUN gem install --no-ri --no-rdoc bundler

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Define working directory.
WORKDIR /home/rails

# Add files.
COPY entrypoint.rb /docker-entrypoint
COPY entrypoint.rb /usr/local/bin/docker-entrypoint
COPY bundle-delete.sh /usr/local/bin/bundle-delete
COPY rails-cleanup.sh /usr/local/bin/rails-cleanup

# Define working directory.
WORKDIR /usr/src/app

# Define volumes.
VOLUME ["/home/rails", "/etc/rails", "/var/lib/rails", "/var/log/rails", "/tmp/rails"]

# Define the entrypoint
ENTRYPOINT ["/docker-entrypoint"]

# Copy the Gemfile into place and bundle.
ONBUILD ADD Gemfile /usr/src/app/Gemfile
ONBUILD ADD Gemfile.lock /usr/src/app/Gemfile.lock
ONBUILD RUN echo "gem: --no-ri --no-rdoc" > ${HOME}/.gemrc
ONBUILD RUN rm -rf .bundle && bundle install --retry 10 --without development test --deployment

# Copy the rest of the application into place.
ONBUILD ADD . /usr/src/app

# Dump out the git revision.
ONBUILD COPY .git/HEAD .git/HEAD
ONBUILD COPY .git/refs/heads .git/refs/heads
ONBUILD RUN \
  cat ".git/$(cat .git/HEAD 2>/dev/null | sed -E 's/ref: (.+)/\1/')" 2>/dev/null > ./REVISION && \
  rm -rf ./.git
