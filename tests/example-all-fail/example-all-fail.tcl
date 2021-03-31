#!/usr/bin/env tclsh

proc isLeapYear {year} {
    return [expr {$year % 2 == 1}]
}
