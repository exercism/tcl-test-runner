# This image includes the 3rd party rl_json library:
#   https://github.com/RubyLane/rl_json
FROM cyanogilvie/tcl

COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENV RUN_ALL=true
ENTRYPOINT ["/opt/test-runner/bin/run.tcl"]
