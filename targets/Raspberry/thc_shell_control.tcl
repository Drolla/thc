#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_server.tcl - THC shell control
# 
# This script allows controlling the THC and zWay services, for example on a
# Raspberry PI ('Razberry').
#
# Copyright (C) 2014 Andreas Drollinger
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

proc Help {} {
	puts "TightHomeControl - Shell Control"
	puts "Call: \[sudo\] thc_shell_control <Command>"
	puts "Available commands"
	puts "  h: This help text"
	puts "  s: Status"
	puts "  zo/za: Stop/start Z-Way service"
	puts "  ro/ra: Stop/start THC service"
	puts "  zl/rl \[options\]: Show Z-way/THC log file"
	puts "  zal/ral: Start Z-Way server/THC and show related log file"
	puts "  so/sa: Stop/start Surveillance"
	puts "  lo/la: All lights off/on"
	puts "  e <TclScript>: Evaluate Tcl script by the THC server"
	puts "  q: Quit the shell control"
	puts "The commands to start and stop the Z-Way and THC service "
	puts "requires root rights (use 'sudo' to run this program)"
}

if {$argv==""} Help

proc AssertRoot {} {
	if {$::tcl_platform(user)!="root"} {
		puts stderr "To execute this operation run this program with root rights"
		puts stderr "Call: sudo $::argv0 $::argv"
		exit 1
	}
}

while {1} {
	if {$argv==""} {
		puts -nonewline "Command: "
		flush stdout
		gets stdin Command
	} else {
		set Command $argv
	}
	if {[catch {
		set CommandArgString [join [lrange $Command 1 end] " "]
		switch -- [lindex $Command 0] {
			h   {Help}
			zl  {
				exec sh -c "tail -n 40 $CommandArgString /var/log/z-way-server.log" >&@ stdout}
			rl  {
				exec sh -c "tail -n 40 $CommandArgString /var/thc/thc.log" >&@ stdout}
			s   {
				set Status [exec sh -c {wget -q -O - 'localhost:8083/JS/Run/Get_Control(["Surveillance","Alarm","AllLights"])'}]
				set Status [split [string trim $Status {[]}] ","]
				puts "Surveillance:[lindex $Status 0], Alarm:[lindex $Status 1], AllLights:[lindex $Status 2]"
			}
			sa  {exec wget -q localhost:8083/JS/Run/SurveillanceOn() -O - >&@ stdout}
			so  {exec wget -q localhost:8083/JS/Run/SurveillanceOff() -O - >&@ stdout}
			la  {exec wget -q localhost:8083/JS/Run/AllLightsOn() -O - >&@ stdout}
			lo  {exec wget -q localhost:8083/JS/Run/AllLightsOff() -O - >&@ stdout}
			ra  {AssertRoot
			     exec /etc/init.d/z-way-server start >&@ stdout
			     exec /etc/init.d/thc.sh start >&@ stdout}
			ro  {AssertRoot
			     exec /etc/init.d/thc.sh stop >&@ stdout}
			za  {AssertRoot
			     exec /etc/init.d/z-way-server start >&@ stdout}
			zo  {AssertRoot
			     exec /etc/init.d/thc.sh stop >&@ stdout
			     exec /etc/init.d/z-way-server stop >&@ stdout}
			zal {AssertRoot
			     exec sh -c "touch /var/log/z-way-server.log" >&@ stdout
				  exec /etc/init.d/z-way-server start >&@ stdout
			     exec sh -c "tail -f /var/log/z-way-server.log" >&@ stdout}
			ral {AssertRoot
			     exec /etc/init.d/z-way-server start >&@ stdout
			     exec touch /etc/init.d/thc.sh >&@ stdout
			     exec /etc/init.d/thc.sh start >&@ stdout
				  exec sh -c "tail -f /var/thc/thc.log" >&@ stdout}
			e {
				set Status [exec sh -c "wget -q -O - 'http://localhost:8085/eval $CommandArgString'"]
				puts "-> $Status"
			}
			q -
			quit {
				puts "Bye"
				exit
			}
		}
	}]} {
		puts "Error: $::errorInfo"
	}
	if {$argv!=""} exit
}