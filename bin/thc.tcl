#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# THC - Tight Home Control
##########################################################################
# thc.tcl - THC's main program
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
	#    are not considered by THC's state update mechanism and by most THC 
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
	#    [-range <ValidValueRange>] - Valid range specification. This is a list 
	#                                 of a min and of a max value. Data outside 
	#                                 of the specified range will be set to unknown ("").
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
	#    >       -set {thc_zWay "SwitchBinary 16.0"}
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
		global DeviceList UpdateDeviceList StickyDevices DeviceUpdate State OldState StickyState Event DeviceAttributes

		if {[lsearch $DeviceList $Device]<0} {lappend DeviceList $Device}
		
		# Default attributes
		set Update 0
		set Sticky 0
		set DeviceAttributes($Device,name) $Device
		set DeviceAttributes($Device,group) ""
		set DeviceAttributes($Device,type) ""
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
				-range {
					set DeviceAttributes($Device,ValidValueRange) $Value}
				-inverse {
					set DeviceAttributes($Device,InverseValue) $Value}
				-gexpr {
					set DeviceAttributes($Device,GetExpression) $Value}
				-type -
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
			set State($Device) ""
			if {[catch {
				Update $Device
				Log {DefineDevice $Device - OK ($State($Device))} 2
			}]} {
				Log {DefineDevice $Device - KO (not accessible!)} 2
			}

			set OldState($Device) $State($Device)
			if {$StickyDevices($Device)} {
				set StickyState($Device) $State($Device)
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
		global State DeviceAttributes
		
		array set ModuleGetCmdList {}
		foreach Device $DeviceList {
			lappend ModuleGetCmdList([lindex $DeviceAttributes($Device,GetCommand) 0]) [lindex $DeviceAttributes($Device,GetCommand) 1]
			lappend ModuleDeviceList([lindex $DeviceAttributes($Device,GetCommand) 0]) $Device
		}
		foreach Module [array names ModuleGetCmdList] {
			set StateList [${Module}::Get $ModuleGetCmdList($Module)]
			foreach Device $ModuleDeviceList($Module) Stat $StateList {
				if {[info exists DeviceAttributes($Device,ValidValueRange)]} {
					if {![string is double $Stat] ||
					    $Stat<[lindex $DeviceAttributes($Device,ValidValueRange) 0] ||
						 $Stat>[lindex $DeviceAttributes($Device,ValidValueRange) 1]} {
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
				set State($Device) $Stat
			}
		}
	}

	##########################
	# Proc: Set
	#    Set device state. This command sets the state for one or multiple 
	#    devices. The updated effective states will be stored immediately inside 
	#    the *State* array variable.
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
		global State DeviceAttributes
		array set ModuleGetCmdList {}
		foreach Device $DeviceList {
			lappend ModuleGetCmdList([lindex $DeviceAttributes($Device,GetCommand) 0]) [lindex $DeviceAttributes($Device,GetCommand) 1]
			lappend ModuleDeviceList([lindex $DeviceAttributes($Device,GetCommand) 0]) $Device
		}
		foreach Module [array names ModuleGetCmdList] {
			set StateList [${Module}::Set $ModuleGetCmdList($Module) $NewState]
			foreach Device $ModuleDeviceList($Module) Stat $StateList {
				set State($Device) $Stat
			}
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

	##########################
	# RegisterDeviceUpdateJobs
	#    Registers the device update jobs. The update information is taken from
	#    the DefineDevice command. This procedure is internally used.
	##########################

	proc RegisterDeviceUpdateJobs {} {
		global DeviceUpdate
		foreach {Update UpdateDeviceList} [array get DeviceUpdate] {
			DefineJob -tag U_$Update -repeat $Update -priority 0 -description "Device update $Update" "Update \{$UpdateDeviceList\}"
		}
	}

######## Job handling ########

# Group: Job handling
# The following commands allow defining and deleting jobs.

	set JobList {}; # Job: {{NextExecTime Priority} Tag RepeatIntervall MinIntervall Description Script}
	set PermanentJobList {}; # Job: {Priority Tag Description Script}
	set JobCount 0; # Job counter


	##########################
	# ParseTime
	#    Parses time in the format accepted by DefineJob.
	#
	# Parameters:
	#    TimeDef -   Time or interval definition. Format corresponds to the one 
	#                supported by DefineJob.
	#    RepeatDef - Defines the way the time is interpreted
	#
	#        - "i"        : Returns a time interval (instead of an absolute Unix 
	#                       time stamp)
	#        - ""         : Returns an absolute Unix time stamp.
	#        - <integer>  : Returns an absolute Unix time stamp. If the time is 
	#                       in the past it is incremented to the next interval.
	#
	# Returns:
	#    Time interval or Unix time stamp
	#    
	# Examples:
	#    > ParseTime 1h1m1s i
	#    >    3661
	#    > ParseTime 11h59m59s ""
	#    >    1420369199
	#    > ParseTime 11:59:59 ""
	#    >    1420282799
	#    > ParseTime 11:59:59 18000
	#    >    1420300799
	#    > ParseTime +11h59m59s ""
	#    >    1420325999
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
		set T 0
		if {[string is integer -strict $TimeDef]} {
			set T $TimeDef
		} elseif {[regexp -nocase {^(\d+[dhms])+$} $TimeDef]} {
			foreach {Symbol Factor} {d 86400 h 3600 m 60 s 1} {
				if {[regexp -nocase "(\\d+)$Symbol" $TimeDef {} Value]} {
					regexp {^0+(\d)} $Value {\1} Value; # Remove leading 0 (to avoid that the number is interpreted as octal value)
					incr T [expr {$Value*$Factor}]
				}
			}
		} elseif {![catch {set T [clock scan $TimeDef]}]} {
			set TimeIsAbsolute 1
		} else {
			return -code error "'$TimeDef' cannot be parsed!"
		}
		if {$RepeatDef!="i"} {
			if {$TimeIsIncremental} {
				set T [expr {$::Time+$T}]
			} elseif {!$TimeIsAbsolute} { # The provided time is an day time
				set T [expr {[clock scan 00:00]+$T}]; # Add the time from the day start time
				if {$T<$::Time} { # Add one day if the evaluated time is in the past
					incr T 86400
				}
			}
		
			# If the time is already in the past and a repetition is defined, go to the next occurrence
			if {$T<$::Time && $RepeatDef!=""} {
				set T [expr {$T+int(ceil(double($::Time-$T)/$RepeatDef)*$RepeatDef)}]
			}
		}
		
		return $T
	}


	##########################
	# Proc: DefineJob
	#    Registers a new job. A job is a command sequence that is executed 
	#    either at a certain moment or in a certain interval.
	#
	#    DefineJob uses the following syntax to specify absolute time and intervals.
	#
	#    [<Y>Y][<M>M][<D>D][<W>W][<h>h][<m>m][<s>s] - Specification of years, 
	#            months, days of the month, week days, hours, minutes and 
	#            seconds. Each unit can be omitted if it's attributed value is 0. 
	#            A value can have one or multiple digits. 
	#            Examples: 01h, 02h35m, 03h74m12s, 09M01D01h, 05W01h30m
	#
	#    The syntax for relative time definitions is identical to the one for 
	#    absolute time definitions, except that the time is prefixed with '+'.
	#
	#    +[<h>h][<m>m][<s>s] - Examples: +01h, +02h35m, +03h74m12s
	#    +<s> - Relative time in seconds. Examples: +5
	#
	# Parameters:
	#    [-tag <Tag>] - 8-character tag. A long string is reduced to 8 characters. Default: 'j<JobCounter>'
	#    [-time <Time>] - Job execution time. Absolute and relative time 
	#            definitions are accepted. Default: "+0" (immediate execution)
	#    [-priority <Priority>] - Priority relative to other jobs that are 
	#            executed at the time. Highest priority is 0, that should only 
	#            be used used for state updates. Default: 20
	#    [-repeat <Repeat>] - Job repetition. Absolute time definitions are 
	#            accepted. If a job needs to be continuously run the repeat time 
	#            has to be set to 0. By default a job is not repeated.
	#    [-init_time <Initial time>] - Optional additional initial job 
	#            execution. Absolute and relative time definitions are accepted.
	#    [-min_intervall <MinimumIntervall> - Minimal interval. A job will not 
	#            be executed if the interval is smaller than the specified one. 
	#            By default there is not minimum interval constraint. Absolute 
	#            time definitions are accepted.
	#    [-description <Description>] - Job description for logging purposes.
	#    <Command> - Command sequence
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > DefineJob -tag AlarmOn -time +0 -description "Start the alarm" {
	#    >    Set $Siren 1}
	#    > DefineJob -tag AlertMail -time +1 -description "Send alert mail" -min_intervall $AlertMailRetriggerT {
	#    >    thc_MailAlert::Send "$Sensor triggered"}
	#    > DefineJob -tag SirenOff -time +$AlarmSireneOffT -description "Stop the alarm siren" {
	#    >    Set $Siren 0}
	#    > DefineJob -tag LightOff -time +$AlarmLightOffT -description "Switch off the alarm lights" {
	#    >    thc_RandomLight::Control 0}
	#    > DefineJob -tag EvalSun -time 01h00m -repeat 24h -init_time +0 -description "Evaluate the sun shine time" {
	#    >    EvaluateSunRiseSunSet}
	#    > DefineJob -tag CopyPng -time 01h -repeat 24h -description "Backup the PNG file" {
	#    >    file copy -force day_log.png day_log_[clock format $Time -format %Y%m%d_%H%M].png
	#    > DefineJob -tag GenGraph -repeat 05m -description "Generate activity graph" {}
	#    > DefineJob -tag GenGraph -repeat 01m -description "1 minute interval RRD log" {}
	#    
	# See also:
	#    <KillJob>
	##########################
	
	proc DefineJob {args} {
		# Option definitions
		Assert {[llength $args]%2==1} "DefineJob, incorrect parameters!"
		# Set default options
		array set Options [list -tag "j$::JobCount" -time "+0" -priority 20 -repeat "" -init_time "" -min_intervall "" -description ""]
		# Override default options with explicitly specified ones
		foreach {OpName OpValue} [lrange $args 0 end-1] {
			Assert {[info exists Options($OpName)]} "DefineJob, unknown option: $OpName!"
		}
		array set Options [lrange $args 0 end-1]

		# Parse all time and interval definitions
		if {[catch {
			set Options(-repeat)        [ParseTime $Options(-repeat) "i"]
			set Options(-time)          [ParseTime $Options(-time) $Options(-repeat)]
			set Options(-init_time)     [ParseTime $Options(-init_time) ""]
			set Options(-min_intervall) [ParseTime $Options(-min_intervall) "i"]
		} Err]} {
			error "DefineJob, $Err"
		}
		
		# Option validity checks
		Assert {$Options(-time)!=""} "DefineJob, no time is defined"
		
		if {$Options(-repeat)!=0} {
			lappend ::JobList [list [list $Options(-time) $Options(-priority)] $Options(-tag) $Options(-repeat) $Options(-min_intervall) $Options(-description) [lindex $args end]]
			if {$Options(-init_time)!=""} {
				lappend ::JobList [list [list $Options(-init_time) $Options(-priority)] $Options(-tag)_i {} $Options(-min_intervall) $Options(-description) [lindex $args end]]
			}
			set ::JobList [lsort -integer -index {0 0} $::JobList]
		} else { # -repeat=0
			lappend ::PermanentJobList [list $Options(-priority) $Options(-tag) $Options(-description) [lindex $args end]]
			set ::PermanentJobList [lsort -integer -index 0 $::PermanentJobList]
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
		foreach JobListVar {::JobList ::PermanentJobList} {
			set JobList {}
			foreach Job [set $JobListVar] {
				if {[lsearch $args [lindex $Job 1]]<0} {
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
	#    Priority0Jobs: If set priority 0 jobs are executed. If not set not 
	#                   priority 0 jobs are executed. This option is used to
	#                   allow the state update jobs before the other jobs.
	##########################

	proc ExecJobs {Priority0Jobs} {
		global JobList Time LastJobExec PermanentJobList
		
		# Execute all permanent jobs
		foreach Job $PermanentJobList {
			if {$Priority0Jobs!=([lindex $Job 0 0]==0)} continue
			Log {Exec [lindex $Job 1] - [lindex $Job 2]} 0
			if {[catch {uplevel #0 [lindex $Job end]}]} {
				Log {Execution of [lindex $Job 1]([lindex $Job 2]) failed! Error: $::errorInfo} 3
			}
		}
		
		# Execute all non-permanent, scheduled jobs
		set Resort 0
		set ExecTagList {}
		set SkippedTagList {}
		while {[llength $JobList]>0 && $Time>=[lindex $JobList 0 0]} {
			set Job [lindex $JobList 0]
			if {$Priority0Jobs!=([lindex $Job 0 0]==0)} continue
			set Tag [lindex $Job 1]

			if {[lindex $Job 3]=="" || ![info exists LastJobExec($Tag)] ||
			    $LastJobExec($Tag)+[lindex $Job 3]<=$Time
			} {
				Log {Exec $Tag - [lindex $Job 4]} 2
				if {[catch {uplevel #0 [lindex $Job end]}]} {
					Log {Execution of ${Tag}([lindex $Job 4]) failed! Error: $::errorInfo} 3
				}
				set LastJobExec($Tag) $Time
			} else {
				Log {Exec $Tag skipped (min interval: [lindex $Job 3])} 1
			}
			
			set Repeat [lindex $Job 2]
			if {$Repeat!={}} {
				lappend ::JobList [list [list [expr [lindex $Job 0 0]+$Repeat] [lindex $Job 0 1]] {*}[lrange $Job 1 end]]
				incr Resort
			}
			set JobList [lrange $JobList 1 end]
		}
		if {$Resort} {
			set JobList [lsort -integer -index {0 0} $::JobList]
			LogJobs
		}
	}

	##########################
	# JobsString
	#    Returns the currently scheduled jobs in form of a formatted string.
	##########################

	proc JobsString {} {
		set line ""
		foreach Job $::JobList {
			set Delay [expr {[lindex $Job 0 0]-$::Time}]
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

	proc LogJobs {} {
		Log [string repeat " " 30][JobsString] 1
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
	#
	# Returns:
	#    Data returned from the HTTP POST transaction
	#    
	# Examples:
	#    > GetUrl "http://ipecho.net/plain"
	#    > -> 188.60.11.219
	##########################
	
	proc GetUrl {Url} {
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
		if {$trials>10} {
			Log {   Host hasn't responded, did $trials trials ($Url)} 3
		} elseif {$trials>1} {
			Log {   Host has responded after $trials trials: value=$value} 3
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

		# Store the updated recovery commands in the recovery file
		if {[catch {
			set f [open $RecoverFile w]
			puts $f "\# THC recovery commands - [clock format [clock seconds]]"
			foreach {Id Command} [array get RecoveryCommands] {
				puts $f "\ncatch \{\n  set RecoveryCommands($Id) \{$Command\}\n  eval \$RecoveryCommands($Id)\n\}"
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
		# recover file doesn't exists)
		catch {uplevel #0 source $::RecoverFile}
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
	proc InitDebug {} {}
	proc LoopDebug {} {}; # Perform 'return -code break' to exit this application
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

	RegisterDeviceUpdateJobs

	# Recover the surveillance state
	RecoverAll

	# Run the main control loop without catching the errors if a debug script is loaded
	InitDebug
	set Event(*) 0
	while {1} {
		Log {THC control loop started} 3
		LogJobs
		catch {
			set Stop 0
			while {!$Stop} {
				LoopDebug

				# State update
				ExecJobs 1; # Run the priority 0 jobs (state updates)
				SaveRecoverDeviceStates; # Save the new states

				#puts State:[array get State]\nOldState:[array get OldState]\nEvent:[array get Event]

				# Update the old (previous) state and the event. Do this update 
				# only if the current state is valid (=not '')
				set Event(*_tmp) 0
				foreach Index $DeviceUpdate(0) { # Evaluate the events and sticky states
					if {$State($Index)!=""} {
						set Event($Index) [expr {$State($Index)!=$OldState($Index)?$State($Index):""}]
						if {$State($Index)!=$OldState($Index)} {
							set Event(*_tmp) 1 }
						set OldState($Index) $State($Index)
						if {$StickyDevices($Index) && ($StickyState($Index)==0 || $StickyState($Index)=="")} {
							set StickyState($Index) $State($Index) }
					}
				}
				if {$Event(*_tmp)} {
					incr Event(*) $Event(*_tmp)
				}
				
				# Wait a tick, and update 'Time' and 'DayTime'
				HeartBeat

				# Run the non state update jobs
				ExecJobs 0
			}
			set Stop 1
		}
		if {$DebugScript==""} { # Normal mode, report the crash and restart
			Log {Crash, info=$errorInfo} 3
			after 60000; # Wait a minute before a new trial is made
			set RecoverSurveillanceState 0
		} else { # Debug mode (raise an error if the program has not been stopped explicitly)
			if {$Stop} break
			Log {Crash, info=$errorInfo} 3
			error "Crash, info=$errorInfo"
		}
	}
	
	Log {THC stopped} 3