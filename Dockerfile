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

# Define working directory.
WORKDIR /tmp

# Install base packages.
RUN apt-get update
RUN apt-get -y install \
    build-essential \
    curl \
    ghostscript \
    git-core \
    imagemagick \
    libcurl4-openssl-dev \
    libreadline-dev \
    libssl-dev \
    libsqlite3-dev \
    libxml2-dev \
    libxslt1-dev \
    libyaml-dev \
    mysql-client \
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
  echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  wget https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
  apt-key add ACCC4CF8.asc && \
  apt-get update && \
  apt-get -y install libpq-dev postgresql-client-9.3 postgresql-contrib-9.3

# Compile node from source.
RUN \
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
  wget http://ftp.ruby-lang.org/pub/ruby/2.1/ruby-2.1.3.tar.gz && \
  tar -xzvf ruby-*.tar.gz && \
  rm -f ruby-*.tar.gz && \
  cd ruby-* && \
  ./configure --disable-install-doc && \
  make && \
  make install && \
  cd .. && \
  rm -rf ruby-*

# Install ruby gems.
RUN gem install bundler rubygems-update --no-ri --no-rdoc

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Define working directory.
WORKDIR /data

# Define mountable directories.
VOLUME ["/data"]
