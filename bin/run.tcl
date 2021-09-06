#!/usr/bin/env tclsh

# Synopsis:
# Run the Tcl test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: absolute path to solution folder
# $3: absolute path to output directory

# Example:
# ./bin/run.tcl two-fer /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

set SPEC_VERSION 2

package require rl_json
namespace import rl_json::json

proc usage {} {
    puts [format "usage: %s %s exercise-slug /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/" \
        [file tail [info nameofexecutable]] \
        $::argv0 \
    ]
    exit 1
}

############################################################
proc runTestFile {slug testsFile inputDir outputFile} {
    puts "Running tests..."

    # Run the tests for the provided implementation file and redirect stdout and
    # stderr to capture it
    set ::env(RUN_ALL) true

    set cwd [pwd]
    cd $inputDir

    set verboseTestsFile [extraTestVerbosity $slug $testsFile]

    try {
        set exitCode 0
        set testOutput [exec tclsh $verboseTestsFile 2>@1]
    } trap CHILDSTATUS {errMsg errData} {
        # exec'ed program exited non-zero
        set exitCode [lindex [dict get $errData -errorcode] end]
        set testOutput $errMsg
    } on error {errMsg errData} {
        # catch any other type of error
        set exitCode -1
        set testOutput $errMsg
    } finally {
        cd $cwd
    }

    # only written for debugging the test runner, otherwise not used
    set fh [open $outputFile w]
    puts $fh $testOutput
    close $fh

    puts "Test run ended: output saved in $outputFile"

    return [list $exitCode $testOutput]
}

# inject extra verbosity into test script
proc extraTestVerbosity {slug testsFile} {
    set verboseTestsFile "$testsFile.verbose"
    set fhIn [open $testsFile r]
    set fhOut [open $verboseTestsFile w]
    while {[gets $fhIn line] != -1} {
        puts $fhOut $line
        if {[regexp "source .*$slug\.tcl" $line]} {
            puts $fhOut "configure -verbose {start body error pass}"
        }
    }
    close $fhIn
    close $fhOut
    return $verboseTestsFile
}

############################################################
proc parseTestOutput {testOutput} {
    set tests {}
    set state None

    foreach line [split $testOutput \n] {
        if {[regexp -- {^[-]{4} (.+) start$} $line -> testname]} {
            set state InTest
            set outputLines {}

        } elseif {[regexp -- {^[+]{4} .+ PASSED$} $line]} {
            set state Passed
            set test [dict create name $testname status pass]
            dict set test output [string trimright [join $outputLines \n]]
            dict set test message ""
            lappend tests $test

        } elseif {[regexp -- {^[=]{4} .+ FAILED$} $line]} {
            if {$state eq "InTest"} {
                # start of test output
                set state CollectingErrs
                set errLines [list $line]

            } elseif {$state eq "CollectingErrs"} {
                # end of test output
                set state None
                lappend errLines $line
                set test [dict create name $testname status fail]
                dict set test message [join $errLines \n]
                dict set test output [string trimright [join $outputLines \n]]
                lappend tests $test
            }
        } else {
            switch -- $state {
                "CollectingErrs" {lappend errLines $line}
                "InTest" {lappend outputLines $line}
            }
        }
    }
    return $tests
}

############################################################
# This will set up a "safe interpreter" where we will override
# some of the test commands and execute the test file
proc getTestBodies {testsFile} {
    set i [interp create -safe]
    $i expose source source
    $i eval {
        rename source tcl_source
        foreach cmd {package namespace source skip cleanupTests} {
            # turn these into no-op commands
            proc $cmd {args} {}
        }
        # don't actually run the test,
        # just map the test name to the test body
        proc test {name desc args} {
            dict set ::testCode $name [dict get $args -body]
        }
        set ::testCode {}
    }
    try {
        $i eval [list tcl_source $testsFile]
        set result [$i eval {set ::testCode}]
    } on error {} {
        set result {}
    }
    return $result
}

############################################################
# Compose the JSON result.
proc jsonResult {status {tests {}} {message ""}} {
    set j [json object]
    json set j version [json number $::SPEC_VERSION]
    json set j status  [json string $status]
    if {$message eq ""} {
        json set j message null
    } else {
        json set j message [json string $message]
    }
    if {[llength $tests] == 0} {
        json set j tests null
    } else {
        set count {pass 0 fail 0 error 0}
        set testsAsJson [json array {*}[lmap tst $tests {
            dict incr count [dict get $tst status]
            list json [jsonTestResult $tst]
        }]]
        puts "Ran [llength $tests] tests: $count"
        json set j tests $testsAsJson
    }
    return [json pretty $j]
}

proc jsonTestResult {tst} {
    set j [json object]
    dict for {key val} $tst {
        if {$val eq ""} {
            json set j $key null
        } else {
            json set j $key [json string $val]
        }
    }
    return $j
}

############################################################
proc main {argv} {
    puts "Running exercise tests for Tcl"

    # If any required arguments is missing, print the usage and exit
    if {[llength $argv] != 3} usage
    foreach arg $argv {
        if {$arg eq ""} usage
    }
    lassign $argv slug inputDir output_dir

    puts "Testing slug: $slug"
    puts "Solution directory: $inputDir"
    puts "Output directory: $output_dir"

    set testsFile "$slug.test"
    set results_file [file join $output_dir results.json]
    set outputFile [file join $output_dir results.out]

    # Create the output directory if it doesn't exist
    file mkdir $output_dir

    lassign [runTestFile $slug $testsFile $inputDir $outputFile] exitCode testOutput
    set tests [parseTestOutput $testOutput]

    # add the test code to the results
    set testBodies [getTestBodies [file join $inputDir $testsFile]]
    set tests [lmap tst $tests {
        set tstname [dict get $tst name]
        if {[dict exists $testBodies $tstname]} {
            dict set tst test_code [dict get $testBodies $tstname]
        }
        set tst
    }]

    puts "Producing JSON report."

    set fh [open $results_file w]
    if {$exitCode == 0} {
        puts $fh [jsonResult pass $tests ""]
    } elseif {[llength $tests] > 0} {
        puts $fh [jsonResult fail $tests ""]
    } else {
        puts $fh [jsonResult error "" $testOutput]
    }
    close $fh

    puts "Wrote JSON report to: $results_file"
}

main $argv
exit 0
