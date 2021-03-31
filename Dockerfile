FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y jq

# Install Tcl
RUN apt-get install -y tcl-thread

# Cleanup
RUN rm -rf /var/lib/apt/lists/* && \
    apt-get purge --auto-remove && \
    apt-get clean

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
