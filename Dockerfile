FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y jq

# Install Tcl
RUN apt-get install -y tcl-thread

# Cleanup
RUN apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
