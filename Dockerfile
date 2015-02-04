#
# Rails application baseimage dockerfile
#
# http://github.com/tenstartups/railsapp-baseimage-docker
#

# Pull base image.
FROM debian:jessie

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment.
ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm
ENV HOME /home/rails
ENV PSQL_HISTORY /home/rails/.psql_history

# Install base packages.
RUN apt-get update
RUN apt-get -y install \
  build-essential \
  curl \
  daemontools \
  ghostscript \
  git \
  imagemagick \
  graphviz \
  libcurl4-openssl-dev \
  libffi-dev \
  libreadline6-dev \
  libssl-dev \
  libsqlite3-dev \
  libxml2-dev \
  libxslt1-dev \
  libyaml-dev \
  mysql-client \
  nano \
  python \
  python-dev \
  python-pip \
  python-software-properties \
  python-virtualenv \
  sqlite3 \
  wget \
  zlib1g-dev

# Add postgresql client from official source.
RUN \
  cd /tmp && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  wget https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
  apt-key add ACCC4CF8.asc && \
  apt-get update && \
  apt-get -y install libpq-dev postgresql-client-9.4 postgresql-contrib-9.4

# Compile node from source.
RUN \
  cd /tmp && \
  wget http://nodejs.org/dist/node-latest.tar.gz && \
  tar xvzf node-*.tar.gz && \
  rm -f node-*.tar.gz && \
  cd node-* && \
  ./configure && \
  CXX="g++ -Wno-unused-local-typedefs" make && \
  CXX="g++ -Wno-unused-local-typedefs" make install && \
  cd .. && \
  rm -rf node-v*

# Compile ruby from source.
RUN \
  cd /tmp && \
  wget http://ftp.ruby-lang.org/pub/ruby/2.2/ruby-2.2.0.tar.gz && \
  tar -xzvf ruby-*.tar.gz && \
  rm -f ruby-*.tar.gz && \
  cd ruby-* && \
  ./configure --disable-install-doc && \
  make && \
  make install && \
  cd .. && \
  rm -rf ruby-*

# Install ruby gems.
RUN gem install awesome_print bundler rubygems-update --no-ri --no-rdoc

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
ONBUILD RUN bundle install --without development test --deployment

# Copy the rest of the application into place.
ONBUILD ADD . /usr/src/app

# Define working directory.
WORKDIR /usr/src/app

# Dump out the git revision.
ONBUILD RUN \
  mkdir -p ./.git/objects && \
  echo "$(git rev-parse HEAD)" > ./build-info.txt && \
  rm -rf ./.git
