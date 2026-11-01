FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

ARG TCL_VERSION=9.1
ARG TCL_PATCH_VERSION=9.1.0

WORKDIR /usr/src
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        bsd-compat-headers \
        openssl-dev \
        zlib-dev \
        tar \
        wget \
        jq \
    && wget https://prdownloads.sourceforge.net/tcl/tcl${TCL_PATCH_VERSION}-src.tar.gz \
    && tar -xzf tcl${TCL_PATCH_VERSION}-src.tar.gz \
    && cd ./tcl${TCL_PATCH_VERSION}/unix \
    && ./configure --enable-threads --prefix=/usr/local \
    && make \
    && make install \
    && ln /usr/local/bin/tclsh${TCL_VERSION} /usr/local/bin/tclsh \
    && cd /usr/src \
    && wget https://prdownloads.sourceforge.net/tcllib/tcllib-2.0.tar.gz \
    && tar -xzf tcllib-2.0.tar.gz \
    && cd ./tcllib-2.0 \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && cd /usr/src \
    && rm -r ./tcl${TCL_PATCH_VERSION}* ./tcllib* \
    && apk del .build-deps

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENV RUN_ALL=true
ENTRYPOINT ["/opt/test-runner/bin/run.tcl"]
