##########################################################################
# THC - Tight Home Control
##########################################################################
# thc::Web_API.tcl - Timer module commands provided to the THC web server
# 
# This module provides all the commands available to the THC web server for THC.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

namespace eval thc::Web::API {

	proc TimerList {} {
		set TimerListJson "\{"
		foreach TimerTask [::thc::Timer::List] {
			append TimerListJson "\"[lindex $TimerTask 0]\":\{"
			append TimerListJson "\"time\":\"[lindex $TimerTask 1]\", "
			append TimerListJson "\"device\":\"[lindex $TimerTask 2]\", "
			append TimerListJson "\"command\":\"[lindex $TimerTask 3]\", "
			append TimerListJson "\"repeat\":\"[lindex $TimerTask 4]\", "
			append TimerListJson "\"description\":\"[lindex $TimerTask 5]\" \}, "
		}
		regsub {,?\s*$} $TimerListJson "\}" TimerListJson
		return [list application/json $TimerListJson]
	}

	proc TimerDelete {args} {
		::thc::Timer::Delete {*}$args
	}
	
	proc TimerDefine {JsonJobDefinition} {
		# puts "TimerDefine: $JsonJobDefinition"

		# JsonJobDefinition: {"time":"2014/12/30 21:46","device":"Surveillance_state","repeat":"20:00"}
		# ListJobDefinition: {"time" "2014/12/30 21:46" "device" "Surveillance_state" "repeat" "20:00"}
		#     JobDefinition: Tcl array
		regsub -all {"[:,]"} $JsonJobDefinition {" "} ListJobDefinition
		array set JobDefinition $ListJobDefinition
		
		regsub -all {/} $JobDefinition(time) {-} JobDefinition(time); # 2015/01/06 22:07 -> 2015-01-06 22:07
		regsub {^(\d+):(\d+)$} $JobDefinition(repeat) {\1h\2m} JobDefinition(repeat); # 20:08 -> 20h:08m
		regsub {^(\d+):(\d+):(\d+)$} $JobDefinition(repeat) {\1h\2m\3s} JobDefinition(repeat); # 20:08:01 -> 20h08m01s
		
		puts "Define $JobDefinition(time) $JobDefinition(device) $JobDefinition(command) $JobDefinition(repeat)"
		::thc::Timer::Define $JobDefinition(time) $JobDefinition(device) $JobDefinition(command) $JobDefinition(repeat)
	}


}; # end namespace thc::Web::API
