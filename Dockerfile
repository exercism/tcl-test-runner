FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y jq tcl-thread && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENV RUN_ALL=true
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
