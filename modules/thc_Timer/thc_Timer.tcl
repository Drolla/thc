##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_Timer.tcl - THC Timer
# 
# This module provides a Timer that allows controlling device states at a 
# certain time, and in a certain interval.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Job timer

# Group: Introduction
#
# This module provides a Timer that allows controlling device states at a 
# certain time, and in a certain interval. User can set and delete timers from 
# the default web application (see <Web interface>). The timer settings are backed 
# up in the recovery file defined by <ConfigureRecoveryFile>, and restored 
# after a restart of THC.

# Group: thc_Timer module commands

namespace eval thc_Timer {

	set TimerCount 0; # Job counter

	##########################
	# Proc: thc_Timer::Define
	#    Registers a new timer task. A timer task allows controlling a device 
	#    state at a certain time and in a certain interval.
	#
	# Parameters:
	#    <Time> -     Timer time. Absolute and relative time definitions are 
	#                 accepted. Supported formats: See the -time argument of <DefineJob>.
	#    <Device> -   Device that will be controlled
	#    <Command> -  Device control command. Allowed commands are: 'On', 
	#                 'Off', 'Switch', 'Set <Value>'. The commands are case insensitive.
	#    [<Repeat>] - Task repetition. Absolute time definitions are accepted. 
	#                 No repetition will be performed if set to "". Supported 
	#                 formats: See the -repeat argument of <DefineJob>.
	#    [<Description>] - Timer description (for logging purposes).
	#
	# Returns:
	#    Timer job identifier
	# 
	# Examples:
	#    > thc_Timer::Define "2015-01-06 08:30" Surveillance,state Off 7d
	#    > -> timer0
	#    > 
	#    > thc_Timer::Define 08h30m LightLiving,state Switch 5m "Light switch"
	#    > -> timer1
	#    
	# See also:
	#    <thc_Timer::Delete>, <thc_Timer::List>
	##########################
	
	proc Define {Time Device Command {Repeat ""} {Description ""} {DoUpdateRecoveryFile 1}} {
		variable TimerCount
		
		# Option definitions
		if {$Description==""} {
			set Description "Timer $TimerCount: $Device $Command @ $Time, rep='$Repeat'"
		}
		set JobTag "timer$TimerCount"
		
		# Define the timer job
		if {[catch {
			::DefineJob -tag $JobTag -time $Time -repeat $Repeat -description $Description \
				[list thc_Timer::StateControl $Device $Command]
		} Err]} {
			regsub {DefineJob} $Err {thc_Timer::Define} Err
			return -code error $Err
		}
		
		incr TimerCount
		if {$DoUpdateRecoveryFile} {
			UpdateRecoveryFile
		}
		return $JobTag
	}


	##########################
	# Proc: thc_Timer::Delete
	#    Delete one or multiple timer tasks.
	#
	# Parameters:
	#    TaskTag - Jobs specified by its tags. This argument can be repeated to 
	#              delete multiple jobs. The 'timer' prefix can be omitted.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_Timer::Delete timer15 timer7
	#    > thc_Timer::Delete 15 7
	#    
	# See also:
	#    <thc_Timer::Define>, <thc_Timer::List>
	##########################

	proc Delete {args} {
		set JobList  {}
		foreach Job $args {
			regsub {^(\d+)$} $Job {timer\1} Job; # add prefix 'timer' if not yet defined
			lappend JobList $Job
		}
		::KillJob {*}$JobList
		UpdateRecoveryFile
	}

	
	##########################
	# Proc: thc_Timer::List
	#    List all active timer tasks. The returned result is a list of timer 
	#    task definitions. Each timer task definition itself is a list composed
	#    by the following elements:
	#    * Task identifier
	#    * Next execution time
	#    * Controlled device
	#    * Device control command
	#    * Repetition
	#    * Description
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    Timer task list
	#    
	# Examples:
	#    > thc_Timer::List
	#    > -> {timer2 {Tue Jan 06 08:30:00 CET 2015} Surveillance,state On {} \
	#    >            {Timer 2: Surveillance,state On @ 2015-01-06 08:30, rep=''}} \
	#    >    {timer3 {Tue Jan 06 09:30:00 CET 2015} Surveillance,state Off 3600 \
	#    >            {Timer 3: Surveillance,state Off @ 2015-01-06 09:30, rep='1h'}}
	#    
	# See also:
	#    <thc_Timer::Define>, <thc_Timer::Delete>
	##########################

	proc List {} {
		set TimerTaskList  {}
		
		# Loop over all defined jobs
		foreach Job $::JobList {
			# Job syntax:         { NextExecTime Tag RepeatIntervall MinIntervall Description Script }
			# Job example:        { {1420533000 100} timer2 3600 {} {Timer 2: Surveillance,state Off @ 2015-01-06 09:30, rep='1h'} {thc_Timer::StateControl Surveillance,state Off} }
			# Timer task example: { timer2 {Tue Jan 06 09:30:00 CET 2015} Surveillance,state Off 3600 {Timer 2: Surveillance,state Off @ 2015-01-06 09:30, rep='1h'} }

			# Skip jobs not related to this timer module
			if {![regexp {^timer} [lindex $Job 1]]} continue

			# Extract the timer task data
			set Time [clock format [lindex $Job 0]]; # Create a human readable data/time string 
			set Tag [lindex $Job 1]
			set Repeat [lindex $Job 2]
			if {[string is integer -strict $Repeat]} {
				set Repeat [format "%2.2dD%2.2dH%2.2dM%2.2dS" [expr $Repeat/24/3600] [expr ($Repeat/3600)%24] [expr ($Repeat/60)%60] [expr $Repeat%60]] }
			set Description [lindex $Job 4]
			regexp {thc_Timer::StateControl\s+([^\s]+)\s+([^\s]+)\s} [info body ::Job($Tag)] - Device Command
			
			# Append the task to the task list
			lappend TimerTaskList [list $Tag $Time $Device $Command $Repeat $Description]
		}
		return $TimerTaskList
	}

	
	##########################
	# thc_Timer::StateControl
	#    Internal command called by the timer. Controls device states.
	#
	# Parameters:
	#    <Device> -  Device that will be controlled
	#    <Command> - Device control command. Allowed commands are: 'On', 
	#
	# Returns:
	#    -
	##########################

	proc StateControl {Device Command} {
		switch -nocase [lindex $Command 0] {
			"on"  {Set $Device 1}
			"off" {Set $Device 0}
			"set" {Set $Device [lindex $Command 1]}
			"switch" {Set $Device [expr {$::State($Device)!="1"}]}
		}
		return
	}
	
	
	proc UpdateRecoveryFile {} {
		foreach TimerTask [List] {
			set Command "thc_Timer::Define \
								\{[lindex $TimerTask 1]\} \{[lindex $TimerTask 2]\} \
								\{[lindex $TimerTask 3]\} \{[lindex $TimerTask 4]\} \{[lindex $TimerTask 5]\} 0"
			DefineRecoveryCommand thc_Timer,[lindex $TimerTask 0] $Command
		}
	}
	

}; # end namespace thc_Timer