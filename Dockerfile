FROM alpine:3.18

ENV NODE_VERSION 21.1.0

# Add user and group (assuming allowed)
RUN addgroup -g 1000 node && adduser -u 1000 -G node -s /bin/sh node

# Install basic dependencies
RUN apk add --no-cache libstdc++ curl

# Detect system architecture
RUN ARCH= OPENSSL_ARCH='linux*' && alpineArch="$(apk --print-arch)"

RUN case "${alpineArch##*-}" in \
  x86_64) ARCH='x64' CHECKSUM="deaf95aceeb446d8861419884fc1d07c54e4a958e4d9b82d8fb9c8f1f7001535" OPENSSL_ARCH=linux-x86_64;; \
  x86) OPENSSL_ARCH=linux-elf;; \
  aarch64) OPENSSL_ARCH=linux-aarch64;; \
  arm*) OPENSSL_ARCH=linux-armv4;; \
  ppc64le) OPENSSL_ARCH=linux-ppc64le;; \
  s390x) OPENSSL_ARCH=linux-s390x;; \
  *) ;; \
esac

# Install pre-built Node.js (if checksum available)
RUN if [ -n "${CHECKSUM}" ]; then \
  set -eu; \
  curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
  echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
fi

# Build Node.js from source (if checksum not available)
RUN if [ -z "${CHECKSUM}" ]; then \
  echo "Building from source" \
  # ... (rest of build commands from original section) ...
fi

# Cleanup (common for both installation methods)
RUN rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" && apk del .build-deps

# Remove unused OpenSSL headers (optional)
RUN find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} \;

# Verify installation
RUN node --version && npm --version

# ENV YARN_VERSION 1.22.19

# RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
#   # use pre-existing gpg directory, see https://github.com/nodejs/docker-node/pull/1895#issuecomment-1550389150
#   && export GNUPGHOME="$(mktemp -d)" \
#   && for key in \
#     6A010C5166006599AA17F08146C2130DFD2497F5 \
#   ; do \
#     gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
#     gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
#   done \
#   && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
#   && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
#   && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
#   && gpgconf --kill all \
#   && rm -rf "$GNUPGHOME" \
#   && mkdir -p /opt \
#   && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
#   && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
#   && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
#   && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
#   && apk del .build-deps-yarn \
#   # smoke test
#   && yarn --version

RUN apk add libressl \
  curl

RUN apk add ca-certificates && update-ca-certificates

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]