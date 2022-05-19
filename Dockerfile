# https://hub.docker.com/r/cyanogilvie/tcl
# includes, among other packages:
#   tcl         8.7a4   http://tcl.tk/software/tcltk/8.7.html 
#   Thread      2.8.6   https://core.tcl-lang.org/thread/dir?ci=tip 
#   tcllib      1.20    https://core.tcl-lang.org/tcllib/doc/tcllib-1-20/embedded/md/toc.md 
#   rl_json     0.11.0  https://github.com/RubyLane/rl_json
#   parse_args  0.3.1   https://github.com/RubyLane/parse_args 
FROM cyanogilvie/tcl:8.7pre3
COPY . /opt/test-runner
WORKDIR /opt/test-runner
ENV RUN_ALL=true
ENTRYPOINT ["/opt/test-runner/bin/run.tcl"]
