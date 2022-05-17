package require rl_json
namespace import ::rl_json::json

#############################################################
# Override some tcltest procs with additional functionality

# Allow an environment variable to override `skip`
proc skip {patternList} {
    if { [info exists ::env(RUN_ALL)]
         && [string is boolean -strict $::env(RUN_ALL)]
         && $::env(RUN_ALL)
    } then return else {
        uplevel 1 [list ::tcltest::skip $patternList]
    }
}

# Exit non-zero if any tests fail.
# The cleanupTests resets the numTests array, so capture it first.
proc cleanupTests {} {
    set failed [expr {$::tcltest::numTests(Failed) > 0}]
    uplevel 1 ::tcltest::cleanupTests
    if {$failed} then {exit 1}
}

#############################################################
# Some procs that are handy for Tcl test custom matching.
# ref http://www.tcl-lang.org/man/tcl8.6/TclCmd/tcltest.htm#M20


# Since Tcl boolean values can be more than just 0/1...
#   set a yes; set b true
#   expr  {$a == $b}     ;# => 0
#   expr  {$a && $b}     ;# => 1
#   expr  {!!$a == !!$b} ;# => 1
#   set a off; set b no
#   expr {$a == $b}      ;# => 0
#   expr {$a && $b}      ;# => 0
#   expr {!!$a == !!$b}  ;# => 1
#
proc booleanMatch {expected actual} {
    return [expr {
        [string is boolean -strict $expected] &&
        [string is boolean -strict $actual] &&
        !!$expected == !!$actual
    }]
}
customMatch boolean booleanMatch


# For testing the test runner, compare the actual results.json to the expected_results.json
# Just check that the test-environment object exists with a value, don't check
# for equality with the expected results: the tclsh version locally and in
# docker may well be different.

proc exercismResultFilesMatch {expected_file actual_file} {
    set actual [readfile $actual_file]
    set expected [readfile $expected_file]

    expr {
        [json get $actual version] == [json get $expected version] &&
        [json get $actual status] eq [json get $expected status] &&
        [json get $actual tests] eq [json get $expected tests] &&
        [json exists $actual "test-environment"] &&
        [json exists $actual "test-environment" tclsh] &&
        [string length [json get $actual test-environment tclsh]] > 0
    }
}
customMatch exercismResultFiles exercismResultFilesMatch

proc readfile {filename} {
    set fh [open $filename]
    set data [read $fh]
    close $fh
    return $data
}
