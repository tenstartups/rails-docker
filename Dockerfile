#
# Rails application docker image
#
# http://github.com/tenstartups/railsapp-docker
#

FROM tenstartups/alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment.
ENV \
  TERM=xterm-color \
  HOME=/home/rails \
  BUNDLE_PATH=./vendor/bundle \
  BUNDLE_APP_CONFIG=./.bundle \
  BUNDLE_SILENCE_ROOT_WARNING=true \
  NOKOGIRI_USE_SYSTEM_LIBRARIES=true \
  PAGER=more \
  RUBY_MAJOR=2.3 \
  RUBY_VERSION=2.3.1 \
  RUBY_DOWNLOAD_SHA256=b87c738cb2032bf4920fef8e3864dc5cf8eae9d89d8d523ce0236945c5797dcd

# Install base packages.
RUN \
  apk --update add \
    autoconf \
    build-base \
    bzip2-dev \
    ca-certificates \
    file \
    font-bitstream-type1 \
    git \
    graphviz \
    imagemagick \
    libffi-dev \
    libgcrypt-dev \
    libpq \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    nodejs \
    openssl-dev \
    postgresql \
    postgresql-dev \
    # https://bugs.ruby-lang.org/issues/11869 and https://github.com/docker-library/ruby/issues/75
    readline-dev \
    rsync \
    tzdata \
    xz \
    yaml-dev \
    zlib-dev \
    && \
  rm -rf /var/cache/apk/*

  # Install ruby from source.
  RUN \
    curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/ruby-${RUBY_VERSION}.tar.gz" && \
    echo "${RUBY_DOWNLOAD_SHA256} *ruby.tar.gz" | sha256sum -c - && \
    mkdir -p /usr/src && \
    tar -xzf ruby.tar.gz -C /usr/src && \
    mv "/usr/src/ruby-$RUBY_VERSION" /usr/src/ruby && \
    rm ruby.tar.gz && \
    cd /usr/src/ruby && \
    { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c && \
    autoconf && \
    # the configure script does not detect isnan/isinf as macros
    ac_cv_func_isnan=yes ac_cv_func_isinf=yes ./configure --disable-install-doc && \
    make -j"$(getconf _NPROCESSORS_ONLN)" && \
    make install && \
    gem update --system && \
  rm -r /usr/src/ruby

  # Install ruby gems.
  RUN \
    mkdir -p /usr/local/etc/ && \
    echo "gem: --no-document" > /usr/local/etc/gemrc && \
    gem install aws-sdk bundler --no-document

# Define working directory.
WORKDIR ${HOME}

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
ONBUILD RUN /usr/local/bin/bundle-gems
ONBUILD RUN /usr/local/bin/compile-assets

# Dump the revision argument to file if present
ONBUILD RUN echo ${BUILD_REVISION} > ./REVISION
