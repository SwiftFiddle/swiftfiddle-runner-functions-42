FROM denoland/deno:bin-1.39.0 AS deno

FROM ubuntu:18.04
LABEL Description="Docker Container for the Swift programming language"

# Install related packages and set LLVM 3.9 as the compiler
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && apt-get -q update && \
    apt-get -q install -y \
    make \
    libc6-dev \
    clang-3.9 \
    curl \
    libedit-dev \
    libpython2.7 \
    libicu-dev \
    libssl-dev \
    libxml2 \
    tzdata \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    pkg-config \
    && update-alternatives --quiet --install /usr/bin/clang clang /usr/bin/clang-3.9 100 \
    && update-alternatives --quiet --install /usr/bin/clang++ clang++ /usr/bin/clang++-3.9 100 \
    && rm -r /var/lib/apt/lists/*

# Everything up to here should cache nicely between Swift versions, assuming dev dependencies change little
ARG SWIFT_PLATFORM=ubuntu18.04
ARG SWIFT_BRANCH=swift-4.2-release
ARG SWIFT_VERSION=swift-4.2-RELEASE

ENV SWIFT_PLATFORM=$SWIFT_PLATFORM \
    SWIFT_BRANCH=$SWIFT_BRANCH \
    SWIFT_VERSION=$SWIFT_VERSION

# Download GPG keys, signature and Swift package, then unpack, cleanup and execute permissions for foundation libs
RUN SWIFT_URL=https://swift.org/builds/$SWIFT_BRANCH/$(echo "$SWIFT_PLATFORM" | tr -d .)/$SWIFT_VERSION/$SWIFT_VERSION-$SWIFT_PLATFORM.tar.gz \
    && curl -fSsL $SWIFT_URL -o swift.tar.gz \
    && export GNUPGHOME="$(mktemp -d)" \
    && set -e; \
    tar -xzf swift.tar.gz --directory / --strip-components=1 \
    && rm -r "$GNUPGHOME" swift.tar.gz \
    && chmod -R o+r /usr/lib/swift

WORKDIR /app

RUN echo 'int isatty(int fd) { return 1; }' | \
  clang -O2 -fpic -shared -ldl -o faketty.so -xc -
RUN strip faketty.so && chmod 400 faketty.so

COPY --from=deno /deno /usr/local/bin/deno

COPY deps.ts .
RUN deno cache deps.ts

ADD . .
RUN deno cache main.ts

EXPOSE 8000
CMD ["deno", "run", "--allow-net", "--allow-run", "main.ts"]
