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

package require json::write

::json::write indented yes
::json::write aligned no

interp alias {} jString {} ::json::write string
interp alias {} jArray  {} ::json::write array
interp alias {} jObject {} ::json::write object

proc usage {} {
    puts [format "usage: %s %s exercise-slug /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/" \
        [file tail [info nameofexecutable]] \
        $::argv0 \
    ]
    exit 1
}

############################################################
# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it
proc runTestFile {slug testsFile inputDir outputFile} {
    puts "Running tests..."

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
        if {[regexp {^\s*configure\s+-verbose} $line]} {
            # ignore user's verbose settings
            set line "## $line"
        }
        puts $fhOut $line
        if {[string match "namespace import *tcltest*" $line]} {
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
    set testname ""
    set errLines {}
    set outputLines {}

    foreach line [split $testOutput \n] {
        if {[regexp -- {^[-]{4} (.+) start$} $line -> testname]} {
            set state InTest
            set outputLines {}

        } elseif {[regexp -- {^[+]{4} .+ PASSED$} $line]} {
            set test [dict create name $testname status pass]
            dict set test output [string trimright [join $outputLines \n]]
            dict set test message ""
            lappend tests $test
            set state None

        } elseif {[regexp -- {^[=]{4} .+ FAILED$} $line]} {
            if {$state eq "InTest"} {
                # start of test output
                set state CollectingErrs
                set errLines [list $line]

            } elseif {$state eq "CollectingErrs"} {
                # end of test output
                lappend errLines $line
                set test [dict create name $testname status fail]
                dict set test message [join $errLines \n]
                dict set test output [string trimright [join $outputLines \n]]
                lappend tests $test
                set state None
            }
        } else {
            switch -- $state {
                "CollectingErrs" {lappend errLines $line}
                "InTest" {lappend outputLines $line}
            }
        }
    }

    # what if we get to the end of the test output without "closing" the last test
    if {$state ne "None"} {
        set test [dict create name $testname status fail]
        dict set test message [join $errLines \n]
        dict set test output [string trimright [join $outputLines \n]]
        lappend tests $test
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
        # turn these tcl and tcltest commands into no-ops,
        # including "unknown" to ignore any unknown commands
        foreach cmd {package namespace source skip cleanupTests configure unknown} {
            proc $cmd {args} {}
        }
        # don't actually run the test,
        # just map the test name to the test information
        proc test {name desc args} {
            try {
                set match [dict get $args -match]
            } on error e {
                set match "exact"
            }
            set testInfo "# code:\n[string trim [dict get $args -body] \n]"
            append testInfo "\n# using $match matching"
            append testInfo "\n# expected value: [dict get $args -result]"
            if {[dict get $args -returnCodes] ne "ok"} {
                append testInfo "\n# expected status: [dict get $args -returnCodes]"
            }

            dict set ::testCode $name $testInfo
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
proc jsonResult {status tests {message ""} {exitCode 0}} {
    set kv_pairs [list]
    lappend kv_pairs version $::SPEC_VERSION
    lappend kv_pairs status  [jString $status]
    lappend kv_pairs "test-exit-status" $exitCode
    lappend kv_pairs "test-environment" [jObject tclsh [jString [info patchlevel]]]

    if {$message eq ""} {
        lappend kv_pairs message null
    } else {
        lappend kv_pairs message [jString $message]
    }
    if {[llength $tests] == 0} {
        lappend kv_pairs tests null
    } else {
        set count {pass 0 fail 0 error 0}
        set testsAsJson [jArray {*}[lmap tst $tests {
            dict incr count [dict get $tst status]
            jsonTestResult $tst
        }]]
        puts "Ran [llength $tests] tests: $count"
        lappend kv_pairs tests $testsAsJson
    }
    return [jObject {*}$kv_pairs]
}

proc jsonTestResult {tst} {
    set kv_pairs [list]
    dict for {key val} $tst {
        if {$val eq ""} {
            lappend kv_pairs $key null
        } else {
            lappend kv_pairs $key [jString $val]
        }
    }
    return [jObject {*}$kv_pairs]
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
        puts $fh [jsonResult pass $tests]
    } elseif {[llength $tests] > 0} {
        puts $fh [jsonResult fail $tests "" $exitCode]
    } else {
        puts $fh [jsonResult error {} $testOutput $exitCode]
    }
    close $fh

    puts "Wrote JSON report to: $results_file"
}

main $argv
exit 0
