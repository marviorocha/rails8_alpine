ARG RUBY_VERSION=3.3.0


FROM library/ruby:$RUBY_VERSION-alpine AS base

RUN apk --update add make g++
RUN apk update && apk add git
RUN apk add --no-cache curl jemalloc vips-dev postgresql-client
RUN apk add --no-cache tzdata

ARG SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_DB_HOST=${RAILS_DB_HOST} \
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    POSTGRES_USER=${POSTGRES_USER} \
    DATABSE_PRODUCTION=${DATABSE_PRODUCTION} \
    REDIS_URL=${REDIS_URL} 


WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_DB_HOST=${RAILS_DB_HOST} \
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    POSTGRES_USER=${POSTGRES_USER} \
    DATABSE_PRODUCTION=${DATABSE_PRODUCTION} \
    REDIS_URL=${REDIS_URL} 


# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build


RUN apk add --update --no-cache \
    binutils-gold \
    build-base \
    openssh \
    curl \
    file \
    g++ \
    gcc \
    git \
    less \
    libstdc++ \
    libffi-dev \
    libc-dev \
    vips-dev \
    jemalloc \
    linux-headers \
    libxml2-dev \
    libxslt-dev \
    libgcrypt-dev \
    make \
    netcat-openbsd \
    nodejs \
    openssl \
    bash \
    sqlite-dev \
    pkgconfig \
    postgresql-dev \
    tzdata \
    yarn \
    imagemagick \
    graphicsmagick-dev \
    ruby-dev \
    musl-dev

# ARG NODE_VERSION=20.18.0
# ARG YARN_VERSION=1.22.22
# ENV PATH=/usr/local/node/bin:$PATH
# RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
#     /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
#     npm install -g yarn@$YARN_VERSION && \
#     rm -rf /tmp/node-build-master

# Install node modules
# COPY package.json yarn.lock ./
# RUN yarn install --frozen-lockfile



# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/


# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN addgroup -S -g 1000 rails && \
    adduser -S -u 1000 -G rails -h /rails -s /bin/ash rails && \
    chown -R rails:rails /rails/db /rails/log /rails/storage /rails/tmp


USER rails
RUN ls -l /rails/bin/
# Entrypoint prepares the database.
ENTRYPOINT ["/bin/sh", "/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
