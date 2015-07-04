#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# THC - Tight Home Control
##########################################################################
# thc.tcl - THC main program
# 
# This file provides the main functionalities of the THC framework. Existing
# extensions are loaded from the 'module' directory.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: THC - Core functions
#
# Group: Introduction
#
# The THC main program provides a set of core functions that are listed below. 
# These functions are completed with additional ones provided by modules.


######## Option definitions ########

	set ThcHomeDir [file dirname [info script]]
	set DebugScript ""; # No default debug script
	set ConfigFile $::ThcHomeDir/../config.tcl; # Default configuration file

	# Overwrite the constants by eventually provided arguments
	
	for {set Indx 0} {$Indx<[llength $argv]} {incr Indx} {
		if {[string index [lindex $argv $Indx] 0]!="-"} {
			error "Wrong argument: [lindex $argv $Indx]"
		}
		set [string range [lindex $argv $Indx] 1 end] [lindex $argv [incr Indx]]
	}
	unset Indx


######## Log ########

# Group: Log
#
# THC provides continuously information about ongoing activities activities, 
# scheduled and executed jobs, and eventually encountered failures. The level
# of detail as well as the log destination is specified with the command 
# <DefineLog>. The command <Log> is available to log a message. It is used by
# THC itself and by the provided extension modules, but it can also be used 
# inside the user scripts and jobs.
#
# The level of detail is defined by the log level which is specified in the 
# following way:
#
#   0 - Everything is logged (every executed job, scheduled jobs, execution 
#         and states of commands provided by THC and its modules, etc)
#   1 - Log jobs not executed every heartbeat, scheduled jobs, execution of 
#         many commands provided by THC and its modules, errors
#   2 - Log jobs not executed every heartbeat, execution of main commands 
#         provided by THC and its modules, errors
#   3 - Logs only important commands and errors

	##########################
	# Proc: DefineLog
	#    Configures the activity logging. DefineLog opens the log file and 
	#    specifies the level of details that will be logged.
	#    By default THC uses a log level of 2 and logs information to the 
	#    standard output. Since the configuration file is loaded not on the 
	#    beginning of the THC startup, some information will always be sent
	#    to the standard output, before the new log destination is specified
	#    inside the configuration file.
	#
	# Parameters:
	#    <LogFile> - Log file name. If the provided log file 'LogFile' is an 
	#                empty string ('') or 'stdout', the log stream is routed 
	#                to stdout
	#    [<LogLevel>] - Log level, default: 2
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > DefineLog stdout 1
	#
	#    > DefineLog "/var/thc/thc_server.log"
	#    
	# See also:
	#    <Log>
	##########################

	proc DefineLog {LogFile {LogLevel 2}} {
		set ::LogLevel $LogLevel
		Log {Log information will be written to $LogFile (level $LogLevel)}
		if {$LogFile=="" || $LogFile=="stdout"} {
			set ::fLog stdout
		} else {
			if {[catch {set ::fLog [open $LogFile a]}]} {
				Log {Failing opening log file $LogFile. Log will be written to stdout}
			}
		}
	}

	##########################
	# Proc: Log
	#    Log a message.
	#
	# Parameters:
	#    <Text> - Text to log, command, variable and backslash substitution will 
	#             be performed in the context of the calling scope.
	#    [<Level>] - Log level, default: 3
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > Log {Switch light on: $Device} 2
	#    
	# See also:
	#    <DefineLog>
	##########################

	proc Log {Text {Level 3}} {
		global fLog Time
		if {[info exists fLog] && $Level>=$::LogLevel} {
			set Text [uplevel 1 "subst \{$Text\}"]
			set Message [format "%s - %s" [clock format $Time -format "%Y.%m.%d,%H:%M:%S"] $Text]
			puts $::fLog $Message
			flush $::fLog
		}
	}

######## Device definitions ########

# Group: Device control
# The following group of commands allows controlling the different devices.

	##########################
	# Proc: DefineDevice
	#    Registers a device. This command registers a device with all 
	#    the information relevant for the device. Once the device is registered
	#    its state is recorded and set via the global commands <Update> and 
	#    <Set>, which call the commands specified respectively with the *-get* 
	#    and *-set* command definition parameters.
	#
	#    A command definition is a list containing as first element the target  
	#    module that supports the device, and as second element detailed device 
	#    information whose format depends on the target module.
	#
	#    The state of a registered device is by default updated automatically 
	#    each heartbeat. A slower update rate can be selected via the option 
	#    *-update*. The provided update time interval uses the same time syntax 
	#    as the absolute time definitions of the <DefineJob> command. It is
	#    recommended to use reasonable slow update rates to reduce the 
	#    interactions with the target devices (e.g. "1h" for battery updates, 
	#    "10m" for weather data updates, etc.).
	#
	#    Devices can be defined that have neither a *-get* nor a *-set* command.
	#    These device are called *dummy* devices. They have no state, and they 
	#    are not considered by the THC state update mechanism and by most THC 
	#    modules. But dummy devices are devices shown by the web access. They
	#    allow adding to the website non state based elements like links, 
	#    images, etc.
	#
	# Parameters:
	#    <Device> - Device identifier
	#    [-get <GetCommandDefinition>] - 'Get' command specification
	#    [-set <SetCommandDefinition>] - 'Set' command specification
	#    [-update <UpdateInterval>] - Update interval, same syntax as for 
	#                                 <DefineJob>, default: 0 (continuous update)
	#    [-sticky 0|1] - Defines sticky behaviour, default: 0
	#    [-range <Range>]   - Valid range specification. This is a list 
	#                         of a min and of a max value. Data outside 
	#                         of the specified range will be set to unknown ("").
	#    [-inverse 0|1]     - Performs logic state inversion, '' is defined if state 
	#                         is not numerical.
	#    [-gexpr <GetExpr>] - Performs an expression evaluation with the 
	#                         obtained value. The originally obtained value is 
	#                         accessed via the variable 'Value' (e.g. $Value-2.0).
	#    [-name <Name>]     - Nice device name (used by the modules: thc_Rrd, thc_Web)
	#    [-type <Type>]     - Device type (used by the modules: thc_Web)
	#    [-group <Group>]   - Device group (used by the modules: thc_Web)
	#    [-format <Format>] - Value format, default: %s (used by the modules: thc_Web)
	#    [-data <Data>]     - Associated data information (used by the modules: thc_Web)
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > ### Devices linked to a physical target ###
	#    > 
	#    > DefineDevice Sirene,state \
	#    >       -get {thc_zWay "SwitchBinary 16.0"} \
	#    >       -set {thc_zWay "SwitchBinary 16.0"} \
	#    >       -type switch
	#    > DefineDevice Dimmer,state \
	#    >       -get {thc_zWay "SwitchMultilevel 16.0"} \
	#    >       -set {thc_zWay "SwitchMultilevel 16.0"} \
	#    >       -type level -range {0 100}
	#    > DefineDevice Sirene,battery -range {0 100} -update 1h \
	#    >       -get {thc_zWay "Battery 16.0"} -gexpr {$Value-0.3}
	#    > 
	#    > ### Virtual device, stores a scenario ###
	#    > 
	#    > DefineDevice Surveillance,state \
	#    >       -name Surveillance -group Scenes -type switch \
	#    >       -get {thc_Virtual "Surveillance"} \
	#    >       -set {thc_Virtual "Surveillance"}
	#    > 
	#    > ### Dummy devices that add elements to the website ###
	#    > 
	#    > DefineDevice zWay,Links \
	#    >       -type link -data http://192.168.1.21:8083
	#    > DefineDevice Environment,1_day \
	#    >       -name Environment -group "Graphs 1 day" \
	#    >       -type image -data $::LogDir/thc_env_1d.png
	#    
	# See also:
	#    <Update>, <Set>, <ResetStickyStates>
	##########################
	
	set UpdateDeviceList {}
	set DeviceList {}
	catch {unset DeviceUpdate}; set DeviceUpdate(0) {}
	catch {unset DeviceAttributes}

	proc DefineDevice {Device args} {
		global DeviceList UpdateDeviceList StickyDevices DeviceUpdate NextState State StickyState Event DeviceAttributes

		if {[lsearch $DeviceList $Device]<0} {lappend DeviceList $Device}
		
		# Default attributes
		set Update 0
		set Sticky 0
		set DeviceAttributes($Device,name) $Device
		set DeviceAttributes($Device,group) ""
		set DeviceAttributes($Device,type) ""
		set DeviceAttributes($Device,range) ""
		set DeviceAttributes($Device,format) "%s"
		set DeviceAttributes($Device,data) {}
		regexp {(.*),(.*)} $Device {} DeviceAttributes($Device,name) DeviceAttributes($Device,group)
		
		# Process all provided attributes
		foreach {Option Value} $args {
			set Command [string totitle [string range $Option 1 end]]
			switch -- $Option {
				-set -
				-get {
					set DeviceAttributes($Device,${Command}Command) $Value}
				-update {
					set Update $Value}
				-sticky {
					set Sticky [expr {$Value!="0"}]}
				-inverse {
					set DeviceAttributes($Device,InverseValue) $Value}
				-gexpr {
					set DeviceAttributes($Device,GetExpression) $Value}
				-type -
				-range -
				-group -
				-format -
				-data -
				-name {
					set DeviceAttributes($Device,[string range $Option 1 end]) $Value}
				default {
					Assert 0 "DefineDevice $Device: Unknown option $Option"
				}
			}
		}

		# Register the device
		set StickyDevices($Device) $Sticky
		
		# If the device has a defined get command:
		# - Register the update information
		# - Try to access the get command
		# - Define the initial states
		if {[info exist DeviceAttributes($Device,GetCommand)]} {
			if {[lsearch $UpdateDeviceList $Device]<0} {lappend UpdateDeviceList $Device}
			lappend DeviceUpdate($Update) $Device
		
			# Run an eventually defined setup command from the relevant interface 
			# module.
			set Module [lindex $DeviceAttributes($Device,GetCommand) 0]
			if {[info command ${Module}::DeviceSetup]!=""} {
				${Module}::DeviceSetup [lindex $DeviceAttributes($Device,GetCommand) 1]
			}

			# Try to access the device (via the Update command (that uses the specified -get command)
			set NextState($Device) ""
			if {[catch {
				Update $Device
				Log {DefineDevice $Device - OK ($NextState($Device))} 2
			}]} {
				Log {DefineDevice $Device - KO (not accessible!)} 2
			}

			set State($Device) $NextState($Device)
			if {$StickyDevices($Device)} {
				set StickyState($Device) $NextState($Device)
			}
			set Event($Device) ""

		# Device has no update command, consider it as dummy device
		} else {
			Log {DefineDevice $Device - Dummy} 2
		}
	}

	##########################
	# Proc: Update
	#    Update device states. The device states will be stored inside the State
	#    array variable. A new state will be set to '' if getting the device
	#    state fails, or if the device state is not within a specified range.
	#
	#    Update has usually not to be called by a user script, since it is 
	#    automatically called for each device in the device specific update 
	#    interval.
	#
	# Parameters:
	#    <DeviceList> - Device list
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > Update {LightCorridor,state Siren,state}
	#    
	# See also:
	#    <Set>
	##########################

	proc Update {DeviceList} {
		global NextState DeviceAttributes
		
		array set ModuleGetCmdList {}
		foreach Device $DeviceList {
			lappend ModuleGetCmdList([lindex $DeviceAttributes($Device,GetCommand) 0]) [lindex $DeviceAttributes($Device,GetCommand) 1]
			lappend ModuleDeviceList([lindex $DeviceAttributes($Device,GetCommand) 0]) $Device
		}
		foreach Module [array names ModuleGetCmdList] {
			set StateList [${Module}::Get $ModuleGetCmdList($Module)]
			foreach Device $ModuleDeviceList($Module) Stat $StateList {
				if {$DeviceAttributes($Device,range)!=""} {
					if {![string is double $Stat] ||
					    $Stat<[lindex $DeviceAttributes($Device,range) 0] ||
						 $Stat>[lindex $DeviceAttributes($Device,range) 1]} {
						set Stat ""
					}
				}
				if {[info exists DeviceAttributes($Device,InverseValue)]} {
					if {[catch {set Stat [expr {!$Stat}]}]} {
						set Stat ""
					}
				}
				if {[info exists DeviceAttributes($Device,GetExpression)]} {
					set Value $Stat; # The expression will use the variable 'Value'
					if {[catch {set Stat [expr $DeviceAttributes($Device,GetExpression)]}]} {
						set Stat ""
					}
				}
				set NextState($Device) $Stat
			}
		}
	}

	##########################
	# Proc: Set
	#    Set device state. This command sets the state for one or multiple 
	#    devices. The updated effective states will be stored inside 
	#    the *NextState* array variable. The state change will be applied
	#    beginning of the next heartbeat cycle (e.g. the *State* array 
	#    variable will be updated).
	#
	# Parameters:
	#    <DeviceList> - Device list
	#    <NewState> - New state
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > Set {LightCorridor,state LightCave,state} 1
	#    
	# See also:
	#    <Update>
	##########################

	proc Set {DeviceList NewState} {
		global NextState DeviceAttributes
		array set ModuleGetCmdList {}
		foreach Device $DeviceList {
			lappend ModuleGetCmdList([lindex $DeviceAttributes($Device,GetCommand) 0]) [lindex $DeviceAttributes($Device,GetCommand) 1]
			lappend ModuleDeviceList([lindex $DeviceAttributes($Device,GetCommand) 0]) $Device
		}
		foreach Module [array names ModuleGetCmdList] {
			set StateList [${Module}::Set $ModuleGetCmdList($Module) $NewState]
			foreach Device $ModuleDeviceList($Module) Stat $StateList {
				set NextState($Device) $Stat
			}
		}
	}


	##########################
	# RegisterDeviceUpdateJobs
	#    Registers the device update jobs. The update information is taken from
	#    the DefineDevice command. This procedure is internally used.
	##########################

	proc RegisterDeviceUpdateJobs {} {
		global DeviceUpdate
		foreach {Update UpdateDeviceList} [array get DeviceUpdate] {
			DefineJob -tag U_$Update -repeat $Update -description "Device update $Update" "Update \{$UpdateDeviceList\}"
		}
	}


######## State updates ########

	##########################
	# UpdateStates
	#    Update the states and the events. Do this update only if the current 
	#    state is valid (=not '').
	##########################

	proc UpdateStates {} {
		global Event UpdateDeviceList NextState State StickyDevices StickyState
		set Event(*_tmp) 0
		foreach Index $UpdateDeviceList { # Evaluate the events and sticky states
			set Event($Index) ""
			if {$NextState($Index)!=$State($Index)} {
				if {$NextState($Index)!=""} {
					set Event($Index) $NextState($Index)
					set Event(*_tmp) 1
					if {$StickyDevices($Index) && ($StickyState($Index)==0 || $StickyState($Index)=="")} {
						set StickyState($Index) $NextState($Index) }
				}
				set State($Index) $NextState($Index)
			}
		}
		if {$Event(*_tmp)} {
			incr Event(*) $Event(*_tmp)
		}
	}
	

	##########################
	# Proc: ResetStickyStates
	#    Reset sticky states. Performs a reset of the registered sticky states.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > ResetStickyStates
	#    
	# See also:
	#    <DefineDevice>
	##########################

	proc ResetStickyStates {} {
		global UpdateDeviceList StickyDevices StickyState
		foreach Device $UpdateDeviceList {
			if {$StickyDevices($Device)} {
				set StickyState($Device) ""
			}
		}
	}


######## Job handling ########

# Group: Job handling
# The following commands allow defining and deleting jobs.

	set JobList {}; # Job: {NextExecTime Tag RepeatIntervall MinIntervall Description Script}
	set PermanentJobList {}; # Job: {Tag Description Script}
	set JobCount 0; # Job counter


	##########################
	# ParseTime
	#    Parses time in the format accepted by DefineJob.
	#
	# Parameters:
	#    TimeDef -   Time or interval definition. Format corresponds to the ones 
	#                supported by DefineJob.
	#    RepeatDef - Defines the way the time is interpreted
	#
	#        - "i"         : Returns a time interval (instead of an absolute Unix 
	#                        time stamp). The returned interval has the format
	#                        accepted by 'clock add' (e.g. '5 days 2 hours').
	#        - ""          : Returns an absolute Unix time stamp.
	#        - <interval>  : Returns an absolute Unix time stamp. If the time is 
	#                       in the past it is incremented to the next interval.
	#
	# Returns:
	#    Time interval or Unix time stamp
	#    
	# Examples:
	#    > ParseTime 1h1m1s i
	#    >    1 hours 1 minutes 1 seconds
	#    > ParseTime 11h59m59s ""
	#    >    1428746399
	#    > ParseTime 11:59:59 ""
	#    >    1428659999
	#    > ParseTime 11:59:59 {5 hours}
	#    >    1428677999
	#    > ParseTime +11h59m59s ""
	#    >    1428703199
	##########################

	proc ParseTime {TimeDef RepeatDef} {
		if {$TimeDef==""} {return ""}
		
		set TimeIsIncremental 0
		set TimeIsAbsolute 0
		if {[string index $TimeDef 0]=="+"} {
			Assert {{$RepeatDef!="i"}} "Time interval cannot start with '+' ('$TimeDef')!"
			set TimeDef [string range $TimeDef 1 end]
			set TimeIsIncremental 1
		}

		# Evaluate a time interval, or a relative time (which is also defined via 
		# a time interval)
		if {$RepeatDef=="i" || $TimeIsIncremental} {
			set I {}
			# The interval is defined via an integer (=number of seconds)
			if {[string is integer -strict $TimeDef]} {
				if {$TimeDef!=0} { # Ignore zero-increments
					lappend I $TimeDef seconds }

			# The interval is defined in the [<Y>Y][<M>M][<W>W][<D>D][<h>h][<m>m][<s>s] format
			} elseif {[regexp {^(\d+[YMWDhms])+$} $TimeDef]} {
				array set TimeLUnit {Y years M months W weeks D days h hours m minutes s seconds}
				foreach {mAll Value Unit} [regexp -all -inline {(\d+)([YMWDhms])} $TimeDef] {
					regexp {^0+(\d)} $Value {\1} Value; # Remove leading 0 (to avoid that the number is interpreted as octal value)
					if {$Value!=0} { # Ignore zero-increments
						lappend I $Value $TimeLUnit($Unit) }
				}
			
			# The interval is defined via a list of value keyword pairs accepted by
			# 'clock add' (e.g. {1 hours 30 minutes}
			} elseif {![catch {clock add 0 {*}$TimeDef}]} {
				set I $TimeDef
			
			# The format is invalid, generate an error
			} else {
				return -code error "Time interval '$TimeDef' cannot be parsed!"
			}

			# If a interval has to be provided, return it.
			if {$RepeatDef=="i"} {
				return $I
			}

			# Transform the relative time into an absolute time.
			set T [clock add $::Time {*}$I]

		# Evaluate an absolute time
		} else {
		
			# The time is defined via an integer (=number of seconds since the epoch)
			if {[string is integer -strict $TimeDef]} {
				set T $TimeDef
			
			# The time is defined in the [<h>h][<m>m][<s>s] style
			} elseif {[regexp {^(\d+[hms])+$} $TimeDef]} {
				array set TimePieces {h 0 m 0 s 0}
				foreach {mAll Value Unit} [regexp -all -inline {(\d+)([YMWDhms])} $TimeDef] {
					regexp {^0+(\d)} $Value {\1} Value; # Remove leading 0 (to avoid that the number is interpreted as octal value)
					incr TimePieces($Unit) $Value
				}
				set T [clock scan "$TimePieces(h):$TimePieces(m):$TimePieces(s)" -base $::Time]
				# puts "clock scan $TimePieces(h):$TimePieces(m):$TimePieces(s) -> $T"
				if {$T<$::Time} { # Add one day if the evaluated time is in the past
					set T [clock add $T 1 days]
				}

			# The time is defined in a style accepted by 'clock scan' (e.g. '09:05:10',
			# '02/25/2016 09:05:10', 'Fri Feb 26 09:05:10 CET 2016'
			} elseif {![catch {set T [clock scan $TimeDef -base $::Time]}]} {
				#if {$T<$::Time} { # Add one day if the evaluated time is in the past
				#	set T [clock add $T 1 days]
				#}
				
			# The format is invalid, generate an error
			} else {
				return -code error "'$TimeDef' cannot be parsed!"
			}
		}

		# If the time is already in the past and a repetition is defined, go to the next occurrence
		if {$T<$::Time && $RepeatDef!=""} {
			# Interval, using as base time '0'. This allows avoiding time switch.
			set Interv [clock add 0 {*}$RepeatDef]
			array set IntervArr $RepeatDef; # Interval array
			set IntervalUnits [array names IntervArr]
			
			# If the interval is less than a day or not a multiple of a day then
			# calculate purely mathematically the next occurrence. This will not
			# respect any time adjustments (e.g. daylight saving time).
			if {$Interv<24*3600 || $Interv%(24*3600)!=0} {
				set T [expr {$T+int(ceil(double($::Time-$T)/$Interv)*$Interv)}]

			# Go to the next occurrence by incrementing the intervals. This will 
			# respect time changes.
			} else {
				while {$T<$::Time} {
					set T [clock add $T {*}$RepeatDef] }
			}
		}
		
		return $T
	}


	##########################
	# Proc: DefineJob
	#    Registers a new job. A job is a command sequence that is executed 
	#    either at a certain moment or in a certain interval. If a job with
	#    the same tag already exists it will be replaced by the new job.
	#
	# Parameters:
	#    [-tag <Tag>] - 8-character tag. A long string is reduced to 8 characters. 
	#            Default: 'j<JobCounter>'
	#    [-time <Time>] - Job execution time. Absolute and relative time 
	#            definitions are accepted (see 'Time definitions'). 
	#            Default: "+0" (immediate execution)
	#    [-repeat <Repeat>] - Job repetition. Absolute time definitions are 
	#            accepted. If a job needs to be continuously run the repeat time 
	#            has to be set to 0. By default a job is not repeated.
	#    [-init_time <Initial time>] - Optional additional initial job 
	#            execution. Absolute and relative time definitions are accepted.
	#    [-min_intervall <MinimumIntervall> - Minimal interval. A job will not 
	#            be executed if the interval from the last execution is smaller 
	#            than the specified one. By default there is not minimum 
	#            interval constraint. Absolute time definitions are accepted.
	#    [-condition <Condition>] - Condition to execute the job. By default the
	#            jobs are executed unconditionally. The condition is evaluated
	#            at the top-level in the global namespace.
	#    [-description <Description>] - Job description for logging purposes.
	#    <Command> - Command sequence that is executed at the top-level in the 
	#                global namespace.
	#
	# Returns:
	#    -
	# 
	# Time definitions:
	#    DefineJob accepts the following time definition formats :
	#
	#       <integer> - The provided integer value is interpreted as number of 
	#            seconds from the epoch time. This is the native manner Tcl 
	#            handles time, e.g. 'clock scan' returns the time in this format. 
	#            Examples: 1428751103 (this corresponds to: Apr 11 13:18:23 CEST 2015)
	#       [<h>h][<m>m][<s>s] - Specification of a day time in hours, minutes and 
	#            seconds. Each unit can be omitted if its attributed value is 0. 
	#            A value can have one or multiple digits (e.g. '5' or '05'). If 
	#            the provided time is in the past in the current day the 
	#            corresponding time in the next day is selected. 
	#            Examples: 01h, 02h35m, 03h74m12s, 09M01D01h, 05W01h30m
	#       <Time/Date string> - Any time/date strings supported by the Tcl 
	#            command 'clock scan' can be used. 
	#            Examples: "13:30", "02/25/2015 13:30"
	#       +<RelativeTime> - By prefixing a time definition with '+' the time can 
	#            be specified relative to the current time. Any formats supported 
	#            for the interval definitions are also supported for the relative 
	#            time definitions (see the next section). A job with a relative 
	#            time of '+0' is executed during the next heartbeat.
	#            Example: +01h, +02h35m, +03h74m12s, +5, +0
	#
	#    If the evaluated time is in the past and an interval is defined then the 
	#    time is moved to the next interval occurrence (see also 'Interval updates'). 
	#    Otherwise the defined job will be executed immediately during the next 
	#    heartbeat.
	#
	# Interval definitions (also used for relative time definitions):
	#    DefineJob accepts the following interval and relative time definition 
	#    formats :
	#
	#       <integer> - The interval corresponds to the provided integer value in 
	#            seconds. The value '0' corresponds to the heartbeat period (e.g. 
	#            the job is executed each heartbeat). Examples: 0, 1, 60, 360
	#       [<Y>Y][<M>M][<W>W][<D>D][<h>h][<m>m][<s>s] - Time interval defined in 
	#            years, months, weeks, days, hours, minutes and seconds. Each unit 
	#            can be omitted if its attributed value is 0. A value can have 
	#            one or multiple digits. 
	#            Examples: 1D, 1M, 2W, 1D15h, 01h, 02h35m, 03h74m12s, 09M01D01h, 05W01h30m
	#       <'Clock add' string> - Time increment definition list accepted by the 
	#            Tcl command 'clock add'. 
	#            Examples: {1 minutes}, {1 days}, {1 hours 30 minutes}
	#
	# Interval update arithmetic:
	#    Interval updates are performed by respecting if necessary months lengths 
	#    and daylight saving time changes. The updates follow the following rules:
	#
	#       * *[<h>h][<m>m][<s>s]*: An interval defined in *hours*, *minutes* and 
	#            *seconds* is an absolute interval; the next occurrence happens 
	#            exactly the specified interval later. 
	#            A 24 hour interval (e.g. '24h') may therefore lead to different 
	#            day time if a daylight saving time adjustment is happening.
	#       * *[<Y>Y][<M>M][<W>W][<D>D]*: For interval definitions in *years*, 
	#            *months*, *weeks* and *days* it is assured that each occurrence 
	#            falls on the same day time as the original occurrence. If 
	#            necessary the interval is extended or reduced by 1 hour to take 
	#            into account daylight saving time changes.
	#       * *[<Y>Y][<M>M]*: For interval definitions in *years* or *months* 
	#            each occurrence falls respectively on the same day and same month 
	#            day as the original occurrence. 
	#            If a day doesn't exist (e.g. Feb 31) the last existing day is 
	#            selected (e.g. Feb 28).
	#
	# Examples:
	#    > # Some definitions
	#    > set AlarmSireneOffT 3m; # Defines how long the sirens have to run after an intrusion
	#    > set AlarmRetriggerT 5m; # Defines minimum alarm retrigger interval
	#    > set AlertMailRetriggerT 45m; # Minimum alert mail retrigger interval
	#    > 
	#    > # Check if any of the specified intrusion detection devices detected an activity:
	#    > proc GetSensorEvent {} {
	#    >   foreach Sensor $::SensorDeviceList {
	#    >     if {$::Event($Sensor)==1} {return 1}
	#    >   }
	#    >   return 0
	#    > }
	#    > 
	#    > # Disable surveillance: Disable a running siren, disable alert related jobs
	#    > DefineJob -tag SurvDis -description "Surveillance disabling" -repeat 0 -condition {$Event(Surveillance,state)==0} {
	#    >   Set $SireneDeviceList 0
	#    >   KillJob AlarmOn AlrtMail SirenOff
	#    > }
	#    > 
	#    > # Intrusion detection
	#    > DefineJob -tag Intrusion -description "Intrusion detection" \
	#    >           -repeat 0 -min_intervall $AlarmRetriggerT \
	#    >           -condition {$State(Surveillance,state)==1 && [GetSensorEvent]} {
	#    >   # An intrusion has been detected: Run new jobs to initiate the alarm and to send alert mails/SMS
	#    > 
	#    >   # Run the sirens (next heartbeat)
	#    >   DefineJob -tag AlarmOn -description "Start the alarm" {
	#    >     Set $SireneDeviceList 1
	#    >   }
	#    > 
	#    >   # Send alert mails (2 seconds later)
	#    >   DefineJob -tag AlrtMail -description "Send alert mail" -min_intervall $AlertMailRetriggerT -time +2s {
	#    >     thc_MailAlert::Send \
	#    >       -to MyAlertMail@MyHome.home \
	#    >       -from MySecuritySystem@MyHome.home \
	#    >       -title "Intrusion detected" \
	#    >       "Intrusion detected, [clock format $Time]"
	#    >   }
	#    > 
	#    >   # Stop running sirens automatically after a while
	#    >   DefineJob -tag SirenOff -description "Stop the alarm siren" -time +$AlarmSireneOffT {
	#    >     Set $SireneDeviceList 0
	#    >   }
	#    > }
	#    
	# See also:
	#    <KillJob>
	##########################
	
	proc DefineJob {args} {
		# Option definitions
		Assert {[llength $args]%2==1} "DefineJob, incorrect parameters!"
		# Set default options
		array set Options [list -tag "j$::JobCount" -time "+0" -repeat "" -init_time "" -min_intervall "" -condition 1 -description ""]
		# Override default options with explicitly specified ones
		foreach {OpName OpValue} [lrange $args 0 end-1] {
			Assert {[info exists Options($OpName)]} "DefineJob, unknown option: $OpName!"
		}
		array set Options [lrange $args 0 end-1]

		# Parse all time and interval definitions
		if {[catch {
			set Options(-repeat_smpl)   [ParseTime $Options(-repeat) "i"]
			set Options(-time)          [ParseTime $Options(-time) $Options(-repeat_smpl)]
			set Options(-init_time)     [ParseTime $Options(-init_time) ""]
			set Options(-min_intervall) [ParseTime $Options(-min_intervall) "i"]
		} Err]} {
			error "DefineJob, $Err"
		}

		# Check if a job is a permanent job (repeat==0 -> repeat interval is empty)
		set IsPermanentJob [expr {$Options(-repeat)!="" && $Options(-repeat_smpl)==""}]
		
		# Option validity checks
		Assert {$Options(-time)!=""} "DefineJob, no time is defined"
		
		# Delete an eventual existing job that has the same tag
		KillJob $Options(-tag)

		# Create the job procedure
		set Tag $Options(-tag)
		set JobProc "proc Job($Tag) \{\} \{\n"
		append JobProc "  uplevel \#0 \{\n"; # "
		if {$Options(-condition)!="" && $Options(-condition)!=1} {
			append JobProc "    if \{!($Options(-condition))\} return\n" }
		if {$Options(-min_intervall)!="" && $Options(-min_intervall)!=1} {
			if {![info exists ::EarliestNextJobExec($Tag)]} {
				set ::EarliestNextJobExec($Tag) -1 }
			append JobProc "    if \{\$Time<\$::EarliestNextJobExec($Tag)\} \{\n"
			append JobProc "      Log \{Cancel $Tag - $Options(-description)\} 1\n"
			append JobProc "      return\}\n"
			append JobProc "    set ::EarliestNextJobExec($Tag) \[clock add \$::Time $Options(-min_intervall)\]\n"
		}
		append JobProc "    Log \{Exec $Tag - $Options(-description)\} [expr {$IsPermanentJob?0:2}]\n\n"
		append JobProc [string trim [lindex $args end] "\n"]
		append JobProc "\n\n  \}\n"
		append JobProc "\}"
		uplevel #0 $JobProc
		#puts $JobProc

		# Permanently executed job: A repeat interval of 0 is defined
		if {$IsPermanentJob} {
			lappend ::PermanentJobList [list $Options(-tag) $Options(-description)]
		} else { # Non permanent job
			lappend ::JobList [list $Options(-time) $Options(-tag) $Options(-repeat_smpl) $Options(-min_intervall) $Options(-description)]
			if {$Options(-init_time)!=""} {
				lappend ::JobList [list $Options(-init_time) $Options(-tag) {} $Options(-min_intervall) $Options(-description)]
			}
			set ::JobList [lsort -integer -index 0 $::JobList]
		}
		
		incr ::JobCount
		return
	}
	
	##########################
	# Proc: KillJob
	#    Kill one or multiple jobs.
	#
	# Parameters:
	#    <JobTag> - Jobs specified via its tags. This argument can be repeated to 
	#               kill multiple jobs.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > KillJob AlarmOn AlrtMail SirenOff LightOff RdmLight
	#    
	# See also:
	#    <DefineJob>
	##########################

	proc KillJob {args} {
		foreach {JobListVar TagIndex} {::JobList 1 ::PermanentJobList 0} {
			set JobList {}
			foreach Job [set $JobListVar] {
				if {[lsearch $args [lindex $Job $TagIndex]]<0} {
					lappend JobList $Job
				}
			}
			set $JobListVar $JobList
		}
	}
	
	##########################
	# ExecJobs
	#    Execute jobs scheduled for the current time.
	#
	# Parameters:
	#    -
	##########################

	proc ExecJobs {} {
		global JobList Time LastJobExec PermanentJobList
		
		# Execute all permanent jobs
		foreach Job $PermanentJobList {
			if {[catch {uplevel #0 Job([lindex $Job 0])}]} {
				Log {Execution of [lindex $Job 0]([lindex $Job 2]) failed! Error: $::errorInfo} 3
			}
		}
		
		# Execute all non-permanent, scheduled jobs
		set Resort 0
		while {[llength $JobList]>0} {
			set Job [lindex $JobList 0]
			if {$Time<[lindex $Job 0]} break
			set JobList [lrange $JobList 1 end]
			set Tag [lindex $Job 1]

			if {[catch {uplevel #0 Job($Tag)}]} {
				Log {Execution of ${Tag}([lindex $Job 4]) failed! Error: $::errorInfo} 3
			}
			
			set Repeat [lindex $Job 2]
			if {$Repeat!={}} {
				set NextTime [clock add [lindex $Job 0] {*}$Repeat]
				lappend JobList [list $NextTime {*}[lrange $Job 1 end]]
				incr Resort
			}
		}

		# Resort the job list if necessary
		if {$Resort} {
			set JobList [lsort -integer -index 0 $JobList]
			LogJobs
		}
	}

	##########################
	# JobsString
	#    Returns the currently scheduled jobs in form of a formatted string.
	##########################

	proc JobsString { {WithPermanentJobs 0} } {
		set line ""
		if {$WithPermanentJobs} {
			foreach Job $::PermanentJobList {
				append line [format "%3s:%-8s " 0s [lindex $Job 0]]
			}
		}
		
		foreach Job $::JobList {
			set Delay [expr {[lindex $Job 0]-$::Time}]
			if {$Delay>=3600} {
				set DelayTxt "[expr {$Delay/3600}]h"
			} elseif {$Delay>=60} {
				set DelayTxt "[expr {$Delay/60}]m"
			} else {
				set DelayTxt "${Delay}s"
			}
			append line [format "%3s:%-8s " $DelayTxt [lindex $Job 1]]
		}
		return $line
	}

	proc LogJobs { {WithPermanentJobs 0} } {
		Log [string repeat " " 30][JobsString $WithPermanentJobs] 1
	}

######## HTTP communication ########

# Group: HTTP communication

	package require http
	
	proc CleanUrl {Url} {
		regsub -all "\\\[" $Url {%5B} Url
		regsub -all "\\\]" $Url {%5D} Url
		regsub -all "\\(" $Url {%28} Url
		regsub -all "\\)" $Url {%29} Url
		regsub -all "\\\"" $Url {%22} Url
		regsub -all "\\ " $Url {%20} Url
		return $Url
	}
	
	##########################
	# Proc: GetUrl
	#    Performs a HTTP POST transaction. GetUrl performs multiple trials 
	#    if a transaction has a timeout. Special URL characters are correctly 
	#    encoded.
	#
	# Parameters:
	#    <URL> - Uniform resource locator/web address
	#    <SafeMode> - If set to 1 (default) no error is generated in case of a connection problem.
	#
	# Returns:
	#    Data returned from the HTTP POST transaction
	#    
	# Examples:
	#    > GetUrl "http://ipecho.net/plain"
	#    > -> 188.60.11.219
	##########################
	
	proc GetUrl {Url {SafeMode 1}} {
		set CleanedUrl [CleanUrl $Url]
		for {set trials 1} {$trials<=10} {incr trials} {
			set value "?"
			set HttpStatus "?"
			set Error [catch {
				set h [::http::geturl $CleanedUrl -query {} -timeout 5000]
				set HttpStatus [::http::status $h]
				set value [http::data $h]
				regexp "^\"(.*)\"$" $value {} value
				::http::cleanup $h
			}]
			if {$HttpStatus!="timeout"} break
			Log {Timeout executing GetUrl $Url, HTTP status: $HttpStatus (trial $trials)} 1
			after 1000
		}
		if {$Error} {
			if {$SafeMode} {
				Log {   Host coulnd't be reached ($Url)} 3
			} else {
				error "Host coulnd't be reached ($Url)" }
		} elseif {$trials>10} {
			if {$SafeMode} {
				Log {   Host hasn't responded, did $trials trials ($Url)} 3
			} else {
				error "Host hasn't responded, did $trials trials ($Url)" }
		} elseif {$trials>1} {
			Log {   Host has responded after $trials trials ($Url} 3
		}
		return $value
	}

######## Utilities ########

# Group: Utilities

	##########################
	# Proc: Assert
	#    Assert a condition. This procedure assert that a condition is 
	#    satisfied. If the provided condition is not true an error is raised.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > Assert {$Value<=1.0} "Define: The maximum allowed value is 1.0"
	##########################

	proc Assert {Condition Message} {
		if {[uplevel 1 expr $Condition]} return
		error $Message
	}

######## Time handling ########

	set HeartBeatCount 0

	proc HeartBeat { {WaitNextBeat 1} } {
		global Time DayTime HeartBeatMS
		after [expr {$WaitNextBeat*$HeartBeatMS}] {incr ::HeartBeatCount}
		vwait ::HeartBeatCount
		set Time [clock seconds]
		set DayTime [expr double($Time-[clock scan 00:00])/3600]
	}

	proc ClockFormat { {Time ""} } {
		if {$Time==""} {
			set Time $::Time
		}
		clock format $Time -format %H:%M:%S
	}

######## State recovery ########

# Group: State recovery
#
# State backup and restore mechanism. THC allows setting up a backup/restore 
# mechanism that allows restoring important device states, variables, etc 
# after a crash once THC is restarted. To use this mechanism a backup file 
# needs to be specified first with <ConfigureRecoveryFile>. Then, devices whose 
# states should be restored can be declared with <DefineRecoveryDeviceStates>. 
# The restoration of custom settings and variables is defined 
# with <DefineRecoveryCommand>.

	##########################
	# Proc: ConfigureRecoveryFile
	#          Defines the recovery file. This file needs to 
	#          be specified before a recovery command or device is defined.
	#
	# Parameters:
	#    <RecoverFile> - Recovery file that stores the device states
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > ConfigureRecoveryFile "/var/thc/thc_server.state"
	##########################

	proc ConfigureRecoveryFile {RecoverFile} {
		set ::RecoverFile $RecoverFile
		return
	}

	
	##########################
	# Proc: DefineRecoveryCommand
	#    Defines a recovery command. The defined command will be added to the
	#    recovery file that is executed if THC restarts. Variables can be
	#    recovered by using 'set' as command.
	#    command.
	#
	# Parameters:
	#    <RecoveryId> - Recovery identifier
	#    [Command] - Recovery command. If omitted a previously defined 
	#                recovery command will be deleted from the recovery file.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > DefineRecoveryCommand DeviceState {Set Surveillance,state 0}
	#    > DefineRecoveryCommand VariableState {set MyVar 123}
	##########################
	
	proc DefineRecoveryCommand {RecoveryId {Command ""}} {
		global RecoveryCommands RecoverFile
		
		# Check if the recovery command has changed
		if {[info exists RecoveryCommands($RecoveryId)] && $RecoveryCommands($RecoveryId) eq $Command} {
			return; # The command has not changed, don't store the restore command set
		}
		
		# Update the recovery definition array
		set RecoveryCommands($RecoveryId) $Command
		if {$Command eq ""} {
			unset -nocomplain RecoveryCommands($RecoveryId)
		}

		# Ignore the data recovery if no recovery file is specified
		if {![info exists RecoverFile]} return

		# Do not update the recover file if DefineRecoveryCommand has been called 
		# during the recovery phase itself
		if {[info exists ::RecoverAllOngoing]} return

		# Store the updated recovery commands in the recovery file
		if {[catch {
			set f [open $RecoverFile w]
			puts $f "\# THC recovery commands - [clock format [clock seconds]]"
			foreach {Id Command} [array get RecoveryCommands] {
				puts $f "\ncatch \{\n  $Command\n\}"
			}
			close $f
		}]} {
			Log {SaveRecoverStates: Recover states couldn't be written into $RecoverFile} 3
		}
		return
	}

	array set RecoveryCommands {}
	
	
	##########################
	# Proc: DefineRecoveryDeviceStates
	#    Defines device states that have to be backed up. The provided arguments 
	#    are the devices whose states need to be backed up, and recovered during 
	#    a restart of THC. Instead of providing as arguments multiple devices
	#    this command can also be executed once per device.
	#
	# Parameters:
	#    <Device>, [<Device>, ...] - List of devices whose states has to be backed up
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > DefineRecoveryDeviceStates Surveillance,state
	##########################

	proc DefineRecoveryDeviceStates {args} {
		lappend ::RecoverDevices {*}$args
	}

	set RecoverDevices {}

	
	##########################
	# SaveRecoverDeviceStates
	#    THC internal command: Checks if the state of one of the recovery device 
	#    states has been changed. Stores all recovery states in the recovery 
	#    file if this is the case.
	##########################
	
	proc SaveRecoverDeviceStates {} {
		global State
		
		# Loop over every each device whose state has to be backed up
		foreach Device $::RecoverDevices {
			# Store the recovery device states. The function 'DefineRecoveryCommand' 
			# will evaluate if the the new device state definition command needs to
			# be stored because it has been changed.
			DefineRecoveryCommand DeviceState,$Device "Set $Device $State($Device)"
		}
	}

	
	##########################
	# RecoverAll
	#    Internal function: Sources the recovery file to restore all objects. 
	#    This function is called at the startup of THC.
	##########################

	proc RecoverAll {} {
		# Source the recovery file. Catch every failure (for example if the 
		# recover file doesn't exists).
		# The recovery file contains calls of the function 'DefineRecoveryCommand'
		# that rewrites itself again the recovery file. To avoid rewriting the 
		# recovery file during its proper execution the variable 'RecoverAllOngoing'
		# is used that indicates when the recovery file is executed.
		set ::RecoverAllOngoing 1
		catch {uplevel #0 source $::RecoverFile}
		unset ::RecoverAllOngoing
	}


######## Include the different modules ########

	set HeartBeatMS 1000; # Update interval in milliseconds. Default is 1000 (ms).
	HeartBeat 0
	DefineLog stdout 2; # Default log destination

	foreach Module [glob -directory "$::ThcHomeDir/../modules" -types f "thc_*.tcl"] {
		if {[catch {source $Module}]} {
			Log {Loading module $Module failed: $errorInfo} 3
			return 1
		}
	}
	foreach Module [glob -directory "$::ThcHomeDir/../modules" -types d "*"] {
		if {[catch {source "$Module/[file tail $Module].tcl"}]} {
			Log {Loading module $Module failed: $errorInfo} 3
			return 1
		}
	}
	unset Module

######## Load the system configuration and check the access to all devices ########

	# Load the debug script if defined
	if {$DebugScript!=""} {
		source $DebugScript
		# Stop the application if no configuration file is specified
		if {$ConfigFile==""} {
			return
		}
	}

	if {[catch {source $ConfigFile}]} {
		Log {Error loading the configuration file 'config.tcl', error: $errorInfo} 3
	}

### Initialization and main control loop ###

	##########################
	# ControlLoop
	#    The procedure ControlLoop runs continuously the control loop. The only
	#    situations this loop is stopped are either a process or debug script 
	#    that sets the global variable ::Stop to 1, or a fatal error of one of 
	#    the commands executed in the control loop.
	##########################

	proc ControlLoop {} {
		set ::Stop 0
		while {!$::Stop} {
			# Job execution
			ExecJobs

			# Wait a tick, and update 'Time' and 'DayTime'
			HeartBeat

			# Update the states and the events.
			UpdateStates

			# Save the new states
			SaveRecoverDeviceStates
		}
	}


	##########################
	# Main
	#    The procedure Main registers first the device update jobs, recovers 
	#    then eventually stored states and calls then the control loop.
	#    If the control loop is stopped non arbitrarily (e.g. not by setting
	#    the variable ::Stop to 1), the control loop is relaunched a minute 
	#    later again if the application is not debugged (e.g. no debug script
	#    is defined).
	##########################
	
	RegisterDeviceUpdateJobs

	# Recover the surveillance state
	RecoverAll

	# Run the main control loop without catching the errors if a debug script is loaded
	set ::Event(*) 0
	while {1} {
		Log {THC control loop started} 3
		LogJobs

		catch {ControlLoop}

		if {$::Stop} break

		Log {Crash, info=$::errorInfo} 3
		if {$::DebugScript==""} { # Normal mode, report the crash and restart
			after 60000; # Wait a minute before a new trial is made
		} else { # Debug mode (raise an error if the program has not been stopped explicitly)
			error "Crash, info=$::errorInfo"
		}
	}
	
	Log {THC stopped} 3