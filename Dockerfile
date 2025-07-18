# https://hub.docker.com/r/cyanogilvie/tcl
# includes, among other packages:
#   tcl         9.0.1   http://tcl.tk/software/tcltk/9.0.html 
#   Thread      3.0.1   https://www.tcl-lang.org/man/tcl9.0/ThreadCmd/index.html
#   incrTcl     4.3.2   https://www.tcl-lang.org/man/tcl9.0/ItclCmd/index.html
#   tcllib      2.0     https://core.tcl-lang.org/tcllib/technote/4a474d8ae3608f1f13ef77049f334be397a18485

# Adding jq package so Tcl track can do CI with the test runner.

FROM alpine:latest

WORKDIR /usr/src
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        bsd-compat-headers \
        openssl-dev \
        zlib-dev \
        tar \
        wget \
        jq \
    && wget https://prdownloads.sourceforge.net/tcl/tcl9.0.1-src.tar.gz \
    && tar -xzf tcl9.0.1-src.tar.gz \
    && cd ./tcl9.0.1/unix \
    && ./configure --enable-threads --prefix=/usr/local \
    && make \
    && make install \
    && ln /usr/local/bin/tclsh9.0 /usr/local/bin/tclsh \
    && cd /usr/src \
    && wget https://prdownloads.sourceforge.net/tcllib/tcllib-2.0.tar.gz \
    && tar -xzf tcllib-2.0.tar.gz \
    && cd ./tcllib-2.0 \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && cd /usr/src \
    && rm -r ./tcl9.0.1* ./tcllib* \
    && apk del .build-deps

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENV RUN_ALL=true
ENTRYPOINT ["/opt/test-runner/bin/run.tcl"]
