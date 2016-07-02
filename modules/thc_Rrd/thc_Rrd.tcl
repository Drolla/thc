##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_Rrd.tcl - THC RRD module
# 
# This module implements an interface to the RRD database. It provides 
# functions to log and plot device states.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Status logging and graph generation

# Group: Introduction
#
# This module implements an interface to the RRD database. It provides 
# functions to log and plot device states.
#
# It requires the Tcl package 'Rrd' or the standalone tool 'Rrdtool'. If 
# both the package and the standalone tool are not available all thc_Rrd 
# commands are simply ignored by THC.


######## RRD ########

# Group: RRD module commands

namespace eval thc_Rrd {

	set RrdTclAvailable [expr ![catch {package require Rrd}]]
	set RrdToolAvailable [expr ![catch {exec rrdtool}]]
	variable RrdFile ""
	variable RrdDeviceList {}

	##########################
	# Proc: thc_Rrd::Open
	#    Creates or opens an RRD database. This command is a wrapper of the RRDTool
	#    create function, using a simplified syntax. If the database doesn't 
	#    exist it will be created. The round robin archives of the database are 
	#    specified via the -rra option. All declared devices are automatically 
	#    added to the database.
	#
	#    If a RRD database already exists it will be extended with eventually 
	#    added new devices if the standalone RRD tools is installed. 
	#
	#    If the standalone RRD tool is not available an existing RRD database 
	#    needs fit exactly the set and order of the defined devices. To add in 
	#    this situation new devices or to change the order of the defined 
	#    devices the existing database needs to be deleted manually.
	#
	# Parameters:
	#    -file <RrdFile> - The name of the RRD database file to open or to create
	#    -step <Step> - Specifies the base interval in seconds with which data 
	#          will be fed into the RRD. This argument corresponds to the --start 
	#          parameter of the 'rrdcreate' RRD library command.
	#    -rra {StepS NbrRow} - Specifies a round robin archive for MAX and AVERAGE 
	#          values. The two provided elements of the list specify the step time 
	#          (in seconds) and the number of rows. This argument can be repeated
	#          to specify multiple round robin archives.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    The following example opens or creates an RRD database that contains
	#    3 MAX and AVERAGE archives :
	#
	#    > thc_Rrd::Open -file /var/thc/thc.rrd -step 60 \
	#    >    -rra [list 1 [expr 26*60]] \
	#    >    -rra [list 5 [expr 33*24*12]] \
	#    >    -rra [list 60 [expr 358*24]]
	#
	#    This example runs the following command under the hood :
	#
	#    > Rrd::create /var/thc/thc.rrd --step 60 --start 1409169540 \
	#    >    DS:Surveillance_state:GAUGE:120:U:U \
	#    >    DS:MotionSalon_state:GAUGE:120:U:U \
	#    >    DS:LightSalon_state:GAUGE:120:U:U \
	#    >    DS:TagReader1_battery:GAUGE:120:U:U \
	#    >    ... \
	#    >    RRA:MAX:0.5:1:1560  RRA:AVERAGE:0.5:1:1560 \
	#    >    RRA:MAX:0.5:5:9504  RRA:AVERAGE:0.5:5:9504 \
	#    >    RRA:MAX:0.5:60:8592 RRA:AVERAGE:0.5:60:8592
	#    
	# See also:
	#    <thc_Rrd::Log>, <thc_Rrd::Graph>, 
	#    RrdCreate documentation on <http://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html>
	##########################

	proc Open {args} {
		global UpdateDeviceList
		variable RrdTclAvailable
		variable RrdToolAvailable

		# Check if the RRD package is available
		::Log {thc_Rrd::Open: Setup the RRD file for the graph generation} 3
		if {!$RrdTclAvailable && !$RrdToolAvailable} {
			::Log { -> Neither Tcl-Rrd package nor Rrd tools are available, graph generation is disabled} 3
			return
		}
		
		# Parse all options
		array set Options {-step 60}
		set RRADefinitions {}
		for {set a 0} {$a<[llength $args]} {incr a} {
			set arg [lindex $args $a]
			switch -- $arg {
				-file -
				-step {
					set Options($arg) [lindex $args [incr a]]}
				-rra {
					# Create the round robin archive (RRA) definitions
					set RraDef [lindex $args [incr a]]
					foreach CF {MAX AVERAGE} {
						lappend RRADefinitions "RRA:$CF:0.5:[lindex $RraDef 0]:[lindex $RraDef 1]"
					}
				}
				default {
					Assert 1 "thc_Rrd::Open: Option '-$arg' is unknown!"
				}
			}
		}
		
		# Create the Rrd device list. Limit the DS name to 18 characters and 
		# remove forbidden characters.
		variable RrdDeviceList {}
		variable RrdDevice2Device
		catch {unset RrdDevice2Device}
		foreach Device $UpdateDeviceList {
			regsub -all {[,.]} [string range $Device 0 18] {_} RrdDevice
			lappend RrdDeviceList $RrdDevice
			set RrdDevice2Device($RrdDevice) $Device
		}
		
		# Check that the file is specified. Create a new Rrd file if not alreay
		# existing. Check if the dataset setup in the current file
		# corresponds to the current set of devices and add new devices if 
		# necessary.
		Assert [info exists Options(-file)] "thc_Rrd::Open: Option '-file' is mandatory!"
		variable RrdFile $Options(-file)
		variable Step $Options(-step)
		if {[file exists $RrdFile]} {
			# Check the existing dataset setup of the current file corresponds to the set of 
			# new devices. This can only happen using the standalone Rrd tools.
			if {!$RrdToolAvailable} {
				::Log { -> Rrd tools are not installed, datasets cannot be verified/completed} 3$
				return
			}
			if {[catch {
				set CurrentRrdDeviceList [RrdGetDeviceList $RrdFile]; # Devices defined in the current Rrd database
			}]} {
				::Log { -> 'Rrdtool info' failed, datasets cannot be verified/completed} 3
				return
			}

			# Create the list of removed devices
			set RemovedRrdDeviceList {}; # Devices defined in the current Rrd database, but not anymore used
			foreach RrdDevice $CurrentRrdDeviceList {
				set CurrentRrdDevice($RrdDevice) 1
				if {![info exists RrdDevice2Device($RrdDevice)]} {
					lappend RemovedRrdDeviceList $RrdDevice
				}
			}
			
			# Create a list if devices that are not yet part of the current Rrd
			# database.
			set MissingRrdDeviceList {}
			foreach RrdDevice $RrdDeviceList {
				if {[lsearch -exact $CurrentRrdDeviceList $RrdDevice]<0} {
					lappend MissingRrdDeviceList $RrdDevice 
				}
			}

			# Inform about not anymore used devices
			if {$RemovedRrdDeviceList!={}} {
				::Log { -> Not anymore used devices: $RemovedRrdDeviceList} 3
			}
			
			# Add the missing devices to the Rrd database if necessary
			if {$MissingRrdDeviceList!={}} {
				::Log { -> Found new devices: $MissingRrdDeviceList} 3
				::Log { -> Trying now to extend current Rrd database ...} 3
				if {[catch {RrdAddDevices $RrdFile $MissingRrdDeviceList} ErrorMsg]} {
					::Log { -> The new devices couldn't be added to the Rrd database, data logging is disabed} 3
					set RrdFile ""
					return
				}
					
				# The Rrd database extension was successful, add the new devices
				# to the Rrd device list variable.
				set RrdDeviceList [concat $CurrentRrdDeviceList $MissingRrdDeviceList]
				::Log " -> New devices have been added. Backup of original database has been created." 3
			} else {
				set RrdDeviceList $CurrentRrdDeviceList; # Use the device order of the existing database
				::Log { -> Use current Rrd database} 3
			}
			return
		}

		# The Rrd database doesn't exist, create a new one
		if {[catch {RrdCreate $RrdFile $RRADefinitions} ErrorMsg]} {
			::Log { -> $ErrorMsg, graph generation is disabled} 3
			variable RrdFile ""; # This indicates to the other procedure that no database is available
			return
		}

		::Log { -> New Rrd file has been created} 3
	}


	##########################
	# thc_Rrd::RrdGetDeviceList
	#    Get the list of devices defined by an Rrd database. An error will be 
	#    generated if the file doesn't exist, or if the Rrd database cannot be 
	#    parsed. This procedure is used by thc_Rrd::Open.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#
	# Returns:
	#    Device list
	#    
	# Examples:
	#    thc_Rrd::RrdGetDeviceList thc.rrd
	##########################

	proc RrdGetDeviceList {RrdFile} {
		if {![file exists $RrdFile]} {
			error "Rrd database '$RrdFile' doesn't exist"
		}

		# Read the Rrd info
		if {[catch {set RrdInfo [exec rrdtool info $RrdFile]}]} {
			error "Rrd database '$RrdFile' cannot be parsed, 'rrdtool info' failed."
		}

		# The existing device setup of the file could be read, parse all device names.
		# The following lines have to be extracted and parsed from the info
		# data (the name in the brackets is the Rrd device name):
		#
		#        ds[MotionSalon_state].index = 3
		#
		set DeviceList {}; # Devices defined in the current Rrd database
		foreach {DsDef RrdDevice} \
			   [regexp -inline -all -line -- {ds\[(.*)\]\.index\s*=\s*\d+} $RrdInfo] {
			lappend DeviceList $RrdDevice
		}
		
		# That's all, return the parsed device list
		return $DeviceList
	}

	
	##########################
	# thc_Rrd::RrdAddDevices
	#    Adds new devices to an existing RRD database. This procedure is used by thc_Rrd::Open.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#    AddedDeviceList - List of new devices that have to be added
	#
	# Returns:
	#    -
	#
	# Examples:
	#    thc_Rrd::RrdAddDevices thc.rrd {Living,temp Living,hum}
	##########################

	proc RrdAddDevices {RrdFile AddedDeviceList} {
		# Dump the current database
		if {[catch {set Data [exec rrdtool dump $RrdFile]}]} {
			error "Current Rrd database '$RrdFile' cannot be dumped".
		}
		
		# Extract the minimal heartbeat from the first device
		regexp {<minimal_heartbeat>\s*(\w+)\s*</minimal_heartbeat>} $Data {} MinimalHeartBeat
		
		# Add the DS definitions
		set InsertData ""
		foreach RrdDevice $AddedDeviceList {
			regsub -all {[,.]} [string range $RrdDevice 0 18] {_} RrdDevice
			append InsertData "<ds>\n"
			append InsertData "  <name> $RrdDevice </name>\n"
			append InsertData "  <type> GAUGE </type>\n"
			append InsertData "  <minimal_heartbeat> $MinimalHeartBeat </minimal_heartbeat>\n"
			append InsertData "  <min>NaN</min>\n"
			append InsertData "  <max>NaN</max>\n"
			append InsertData "  \n"
			append InsertData "  <!-- PDP Status -->\n"
			append InsertData "  <last_ds> U </last_ds>\n"
			append InsertData "  <value> 0.0000000000e+00 </value>\n"
			append InsertData "  <unknown_sec> 0 </unknown_sec>\n"
			append InsertData "</ds>\n"
		}
		regsub {(<!-- Round Robin Archives -->)} $Data "$InsertData\\1" Data

		# Add the DS data
		set InsertData ""
		foreach RrdDevice $AddedDeviceList {
			append InsertData "<ds>\n"
			append InsertData "  <primary_value>NaN</primary_value>\n"
			append InsertData "  <secondary_value>NaN</secondary_value>\n"
			append InsertData "  <value>NaN</value>\n"
			append InsertData "  <unknown_datapoints>0</unknown_datapoints>\n"
			append InsertData "</ds>\n"
		}
		regsub -all {(</cdp_prep>)} $Data "$InsertData\\1" Data
		
		# Add empty entries to the database
		set InsertData ""
		foreach RrdDevice $AddedDeviceList {
			append InsertData "<v>NaN</v>"
		}
		regsub -all {(</row>)} $Data "$InsertData\\1" Data

		# Backup the database, and restore it with the new device definitions
		set BackupFileName ${RrdFile}.old_[clock seconds]
		if {[catch {file rename $RrdFile $BackupFileName}]} {
			error "The original file cannot be backed up."
		}
		if {[catch {exec rrdtool restore - $RrdFile << $Data}]} {
			file delete $RrdFile
			file rename $BackupFileName $RrdFile
			error "The Rrd database cannot be extended (read only of the directory?)"
		}
		
		# The Rrd database extension was successful
		return
	}


	##########################
	# thc_Rrd::RrdRenameDevices
	#    Renames devices of an existing RRD database.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#    DeviceUpdateList - List of old and new device identifier pairs
	#
	# Returns:
	#    -
	#
	# Examples:
	#    thc_Rrd::RrdRenameDevices thc.rrd {Living,temp Living,temperature Living,hum Living,humidity}
	##########################

	proc RrdRenameDevices {RrdFile DeviceUpdateList} {

		# Dump the current database
		if {[catch {set Data [exec rrdtool dump $RrdFile]}]} {
			error "Current Rrd database '$RrdFile' cannot be dumped".
		}
		
		# Rename the devices
		foreach {OldDeviceId NewDeviceId} $DeviceUpdateList {
			regsub -all {[,.]} [string range $OldDeviceId 0 18] {_} OldDeviceId
			regsub -all {[,.]} [string range $NewDeviceId 0 18] {_} NewDeviceId
			regsub -all "\\m$OldDeviceId\\M" $Data "$NewDeviceId" Data
		}

		# Backup the database
		set BackupFileName ${RrdFile}.old_[clock seconds]
		if {[catch {file rename $RrdFile $BackupFileName}]} {
			error "The original file cannot be backed up."
		}

		# Restore the updated database
		if {[catch {exec rrdtool restore - $RrdFile << $Data}]} {
			file delete $RrdFile
			file rename $BackupFileName $RrdFile
			error "The Rrd database cannot be extended (read only of the directory?)"
		}

		# The update was successfull, delete the backup file
		file delete $BackupFileName
		
		# The Rrd database extension was successful
		return
	}


	##########################
	# thc_Rrd::RrdRemoveDevices
	#    Adds new devices to an existing RRD database. This procedure is used by thc_Rrd::Open.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#    RemovedDeviceList - List of devices that have to be removed
	#
	# Returns:
	#    -
	#
	# Examples:
	#    thc_Rrd::RrdRemoveDevices thc.rrd {Living,humidity}
	##########################

	proc RrdRemoveDevices {RrdFile RemovedDeviceList} {
		variable Step
	
		# Dump the current database
		if {[catch {set Data [exec rrdtool dump $RrdFile]}]} {
			error "Current Rrd database '$RrdFile' cannot be dumped".
		}
		
		foreach RemoveDevice $RemovedDeviceList {
			regsub -all {[,.]} [string range $RemoveDevice 0 18] {_} RemoveDevice

			# Parse the DS definitions, evaluate the device index
			set AllDeviceDefs [regexp -inline -all {<ds>\s*?<name>\s*?(\w+)\s*?</name>.*?</ds>} $Data]
			set NbrRrdDevices [expr [llength $AllDeviceDefs]/2]
			set DeviceIndex 0
			foreach {DeviceDef Device} $AllDeviceDefs {
				if {$Device==$RemoveDevice} break
				incr DeviceIndex
			}
			if {$DeviceIndex>=$NbrRrdDevices} {
				error "Device $RemoveDevice is not part of the Rrd database"
			}
		
			# Remove all DS tags of the relevant device (in the reverse order)
			set AllDsDefs [regexp -all -indices -inline -- {<ds>.*?</ds>} $Data]
			for {set Index [expr [llength $AllDsDefs]-$NbrRrdDevices+$DeviceIndex]} {$Index>=0} {incr Index -$NbrRrdDevices} {
				set Data [string replace $Data {*}[lindex $AllDsDefs $Index]]
			}
		
			# Remove the log values
			set RegExpPattern "(<row>[string repeat {<v>.*?</v>} $DeviceIndex])<v>.*?</v>([string repeat {<v>.*?</v>} [expr $NbrRrdDevices-$DeviceIndex-1]]</row>)"
			regsub -all $RegExpPattern $Data {\1\2} Data
		}

		# Backup the database, and restore it with the new device definitions
		set BackupFileName ${RrdFile}.old_[clock seconds]
		if {[catch {file rename $RrdFile $BackupFileName}]} {
			error "The original file cannot be backed up."
		}
		if {[catch {exec rrdtool restore - $RrdFile << $Data}]} {
			file delete $RrdFile
			file rename $BackupFileName $RrdFile
			error "The Rrd database cannot be extended (read only of the directory?)"
		}
		
		# The Rrd database extension was successful
		return
	}

	
	##########################
	# thc_Rrd::RrdModifyDeviceValues
	#    Modify the values of a devices in an existing RRD database.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#    Device - Device for which the values have to be changed
	#    Expression - Value recalculation expression. The expression has to
	#                 refer the original value via the variable 'Value'. To 
	#                 invalidate a value set it to an empty string ("") and not
	#                 to "NaN"
	#                 Expression examples: $Value*1.23, ($Value<0?"":$Value)
	#
	# Returns:
	#    -
	#
	# Examples:
	#    thc_Rrd::RrdModifyDeviceValues thc.rrd "Living,temperature" {$Value+1.3}
	##########################

	proc RrdModifyDeviceValues {RrdFile Device Expression} {
		variable Step
		
		# Check the expression
		set Value 123
		if {[catch {expr $Expression}]} {
			error "Expression '$Expression' cannot be evaluated. Correct examples: '\$Value*1.23', '{\$Value<0.0?\"NaN\":\$Value}'" }
	
		# Dump the current database
		if {[catch {set Data [exec rrdtool dump $RrdFile]}]} {
			error "Current Rrd database '$RrdFile' cannot be dumped." }
		
		# Replace characters not supported by Rrd
		regsub -all {[,.]} [string range $Device 0 18] {_} RrdDevice

		# Parse the DS definitions, evaluate the device index
		set AllDeviceDefs [regexp -inline -all {<ds>\s*?<name>\s*?(\w+)\s*?</name>.*?</ds>} $Data]
		set NbrRrdDevices [expr [llength $AllDeviceDefs]/2]
		set DeviceIndex [expr ([lsearch -exact $AllDeviceDefs $RrdDevice]-1)/2]
		if {$DeviceIndex<0} {
			error "Device $Device is not part of the Rrd database" }
		
		# Create the regex pattern to modify all values of the relevant device
		set RegExpPattern "<row>[string repeat {<v>.*?</v>} $DeviceIndex]<v>(.*?)</v>[string repeat {<v>.*?</v>} [expr $NbrRrdDevices-$DeviceIndex-1]]</row>"

		# Change all values of the device. Start at the end to avoid a conflict with the location indexes
		set LastIndex 0
		set NewData ""
		foreach {RowIndex ValueIndex} [regexp -line -all -inline -indices $RegExpPattern $Data] {
			append NewData [string range $Data $LastIndex [lindex $ValueIndex 0]-1]
			set Value [string range $Data {*}$ValueIndex]
			# Change the value, in case of an error change the value into 'NaN'
			if {$Value eq "NaN"} { # No change, ignore NaN
			} elseif {[catch {set Value [expr $Expression]}] || ($Value eq "")} {
				set Value "NaN" }
			append NewData $Value
			set LastIndex [expr {[lindex $ValueIndex 1]+1}]
		}
		append NewData [string range $Data $LastIndex end]

		# Backup the database, and restore it with the new device definitions
		set BackupFileName ${RrdFile}.old_[clock seconds]
		if {[catch {file rename $RrdFile $BackupFileName}]} {
			error "The original file cannot be backed up." }
		if {[catch {exec rrdtool restore - $RrdFile << $NewData}]} {
			file delete $RrdFile
			file rename $BackupFileName $RrdFile
			puts stderr "Error: $::errorInfo"
			error "The Rrd database cannot be extended (read only of the directory?)"
		}
		
		# The Rrd database extension was successful
		return
	}

	
	##########################
	# thc_Rrd::RrdCheckDeviceValueRange
	#    Check the valid range of the values of a devices in an existing RRD 
	#    database. Invalid values are marked as NaN
	#
	# Parameters:
	#    RrdFile   - The name of the RRD database file
	#    Device    - Device for which the values have to be changed
	#    LowLimit  - Lower limit of the valid value range
	#    HighLimit - Higher limit of the valid value range
	#
	# Returns:
	#    -
	#
	# Examples:
	#    thc_Rrd::RrdCheckDeviceValueRange thc.rrd "Living,temperature" -5 40
	##########################

	proc RrdCheckDeviceValueRange {RrdFile Device LowLimit HighLimit} {
		thc_Rrd::RrdModifyDeviceValues $RrdFile $Device \
			"(\$Value<$LowLimit || \$Value>$HighLimit ? \"\" : \$Value)"
	}

	
	##########################
	# thc_Rrd::RrdCreate
	#    Creates a new RRD database. This procedure is used by thc_Rrd::Open.
	#
	# Parameters:
	#    RrdFile - The name of the RRD database file
	#    RRADefinitions - RRA definitions
	#
	# Returns:
	#    -
	##########################

	proc RrdCreate {RrdFile RRADefinitions} {
		variable RrdTclAvailable
		variable RrdToolAvailable
		variable RrdDeviceList
		variable Step
		global Time

		# Create the data source (DS) definitions for each device.
		foreach RrdDevice $RrdDeviceList {
			lappend RrdDSList DS:$RrdDevice:GAUGE:[expr 2*$Step]:U:U
		}

		# Build the arguments for Rrd_create
		set CmdArgs [list --step $Step --start [expr $Time-$Step] {*}$RrdDSList {*}$RRADefinitions]
		
		# Create the database using the Tcl-Rrd package or the standalone Rrdtool executable
		if {$RrdTclAvailable} {
			if {![catch {
				::Log {Rrd file creation: $CmdArgs} 1
				Rrd::create $RrdFile {*}$CmdArgs
			}]} return
		}
		if {$RrdToolAvailable} {
			if {![catch {
				::Log {Rrd file creation: $CmdArgs} 1
				exec rrdtool create $RrdFile {*}$CmdArgs]
			}]} return
		}
		
		error "The database couldn't be created: $::errorInfo"
	}


	##########################
	# Proc: thc_Rrd::Log
	#    Logs the devices states. This command calls the RRDTool update 
	#    function. The states of all declared devices is written to the opened 
	#    RRD database.
	#
	#    For devices that have a sticky state, this sticky state is written 
	#    instead of the instantaneous state. The sticky states has usually to 
	#    be cleared with <ResetStickyStates> after having logged them by 
	#    thc_Rrd::Log.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_Rrd::Log; ResetStickyStates
	#    
	# See also:
	#    <thc_Rrd::Open>, <thc_Rrd::Graph>, <ResetStickyStates>,
	#    RrdUpdate documentation on <http://oss.oetiker.ch/rrdtool/doc/rrdupdate.en.html>
	##########################

	proc Log {} {
		global Time State StickyState UpdateDeviceList
		variable RrdTclAvailable
		variable RrdToolAvailable
		variable RrdFile
		variable Step
		if {$RrdFile==""} return

		# Log the state of each device. If a state is not defined report 'U' (
		# RRD symbol for undefined values). Use the device names also used by 
		# 'Open'.
		variable RrdDeviceList
		variable RrdDevice2Device
		foreach RrdDevice $RrdDeviceList {
			set Value "U"
			catch {
				set Device $RrdDevice2Device($RrdDevice)
				set Value [expr $State($Device)]
				set Value [expr $StickyState($Device)]; # Use the sticky state if existing
			}
			lappend StateList $Value
		}
	
		# Add the device states to the RRD database (via the rrdupdate command)
		::Log {Rrd::update \"$RrdFile\" $Time:[join $StateList :]} 1
		if {[catch {
			if {$RrdTclAvailable} {
				Rrd::update $RrdFile $Time:[join $StateList ":"]
			} else {
				exec rrdtool update $RrdFile $Time:[join $StateList {:}]
			}
		}]} {
			::Log {RrdLog error: ($::errorInfo)} 3
		}
	}

	##########################
	# thc_Rrd::GetColorList
	#    Generates a set of <NbrColors> distinctive colors.
	#    The algorithm has been found on:
	#    <http://stackoverflow.com/questions/470690/how-to-automatically-generate-n-distinct-colors>
	##########################

	proc GetColorList {NbrColors} {
		set SubDivs [expr int(floor(pow($NbrColors,1.0/3)))]
		for {set r 0} {$r<256} {incr r [expr {255/$SubDivs}]} {
			for {set g 0} {$g<256} {incr g [expr {255/$SubDivs}]} {
				for {set b 0} {$b<256} {incr b [expr {255/$SubDivs}]} {
					lappend ColorList [format %2.2X%2.2x%2.2x $r $g $b] }}}
		return [lrange $ColorList 0 $NbrColors-1]
	}

	##########################
	# Proc: thc_Rrd::Graph
	#    Generates a graph picture. This command calls the RRDTool graph 
	#    function. The -type option allows specifying if the graphs have to be 
	#    plotted overlaying (analog values), or if they have to be stacked 
	#    (digital values).
	#    
	#    The graph formats are controlled via the -rrd_arguments option that is
	#    directly forwarded to the underlying rrdgraph command.
	#    
	#    Finally, the devices that have to be plotted are provided as remaining 
	#    arguments. See the example below that shows how device groups can be
	#    built with the 'array names' command that is applied on the 
	#    GetDeviceCommand array variable.
	#    
	#    By specifying a dummy device the generated images can be displayed on
	#    the website (see <DefineDevice>).
	#
	# Parameters:
	#    -file <PictureFile> - The name and path of the graph file to generate. 
	#             It is recommended to end this in .png, .svg or .eps.
	#    -type binary|analog - Specifies the type of the plotted values. Analog 
	#             values (default) are plotted overlaying. Digital values are 
	#             plotted stacked.
	#    -rrd_arguments <RrdGraphOptions> - The options provided in this list 
	#             are directly forwarded to the rrdgraph command. For details 
	#             consult the rrdgraph documentation.
	#    <Device> <Device> ... - List of devices to plot. A device can be 
	#             specified by a 2 element list. The first element is in this
	#             case the device name, and the second element a scale RPN 
	#             expression (see references)
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    Plot of binary device states:
	#    > thc_Rrd::Graph \
	#    >   -file $::LogDir/thc.png \
	#    >   -type binary \
	#    >   -rrd_arguments [list \
	#    >      --title "Surveillance and Alarm Activities - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
	#    >      --x-grid MINUTE:10:HOUR:1:HOUR:3:0:%b%d,%Hh \
	#    >      --alt-autoscale \
	#    >      --end $Time --start end-26h --step 60 --height 300 --width 1560] \
	#    >   Surveillance,state Alarm,state AllLights,state \
	#    >   {*}[lsearch -all -inline $DeviceList Motion*,state] \
	#    >   {*}[lsearch -all -inline $DeviceList Window*,state] \
	#    >   {*}[lsearch -all -inline $DeviceList Light*,state]
	#
	#    Plot of analog device states :
	#    > thc_Rrd::Graph \
	#    >   -file $::LogDir/thc_bat.png \
	#    >   -type analog \
	#    >   -rrd_arguments [list \
	#    >      --title "Battery level - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
	#    >      --vertical-label "Battery level (%)" \
	#    >      --x-grid MINUTE:10:HOUR:1:HOUR:3:0:%b%d,%Hh \
	#    >      --alt-autoscale \
	#    >      --end $Time --start end-26h --step 60 --height 300 --width 1560] \
	#    >   {*}[lsearch -all -inline $DeviceList *,battery]
	#
	#    Plot two analog device states with different scales :
	#    > thc_Rrd::Graph \
	#    >   -file $::LogDir/thc_env.png \
	#    >   -type analog \
	#    >   -rrd_arguments [list \
	#    >      --title "Temperature and Humidity - [clock format $Time -format {%A, %Y.%m.%d, %H:%M:%S}]" \
	#    >      --vertical-label "Temperature (C)" --right-axis-label "Humidity (%)" \
	#    >      --x-grid MINUTE:10:HOUR:1:HOUR:3:0:%b%d,%Hh \
	#    >      --right-axis 5:-35 --alt-autoscale \
	#    >      --end $Time --start end-26h --step 60 --height 300 --width 1560 \
	#    >   Living,temp {Living,hum ",35,+,5,/"}
	#
	#    Display the generated image in the website: Use a dummy device :
	#    > DefineDevice Battery,26hours \
	#    >       -name Battery -group "Graphs 26 hours" \
	#    >       -type image -data $::LogDir/thc_bat.png
	#
	# See also:
	#    <thc_Rrd::Open>, <thc_Rrd::Log>, 
	#    RrdGraph  documentation on <http://oss.oetiker.ch/rrdtool/doc/rrdgraph.en.html>, 
	#    Rrd RPN documentation on <http://http://oss.oetiker.ch/rrdtool/doc/rrdgraph_rpn.en.html>
	##########################

	proc Graph {args} {
		global DeviceAttributes
		variable RrdFile
		variable RrdTclAvailable
		variable RrdToolAvailable
		if {$RrdFile==""} return

		# Parse the arguments
		array set Options {-type analog -rrd_arguments ""}
		set DeviceList {}
		for {set a 0} {$a<[llength $args]} {incr a} {
			set arg [lindex $args $a]
			switch -- $arg {
				-file -
				-type -
				-rrd_arguments {
					set Options($arg) [lindex $args [incr a]]}
				default {
					lappend DeviceList $arg
				}
			}
		}
		
		# Argument checks:
		Assert [info exists Options(-file)] "thc_Rrd::Graph: Option '-file' is mandatory!"
		Assert [llength $DeviceList] "thc_Rrd::Graph: Device list is empty"

		# Generate a list of distinctive colors
		set ColorList [GetColorList [llength $DeviceList]]

		# Generate the data definition, data calculation and graph element lists
		set DefList {}
		set CDefList {}
		set LineList {}
		set Count [expr [llength $DeviceList]-1]
		foreach Device $DeviceList Color $ColorList {
			# Extract an eventually provided RPN expression and cleanup the device name
			set RpnExpression [lindex $Device 1]
			set DeviceName $DeviceAttributes([lindex $Device 0],name)
			regsub -all {[,.]} [string range [lindex $Device 0] 0 18] {_} Device
			
			# Plot binary values stacked, based on the device counter variable:
			if {$Options(-type)=="binary"} {
				lappend DefList "DEF:$Device=$RrdFile:$Device:MAX"
				lappend CDefList "CDEF:d$Device=$Device,0.6,*,[expr $Count+0.02],+"
				lappend LineList "LINE:d$Device#$Color:$DeviceName"
				incr Count -1
			
			# Plot analog values overlaying
			} else {
				lappend DefList "DEF:$Device=$RrdFile:$Device:AVERAGE"
				lappend CDefList "CDEF:d$Device=${Device}${RpnExpression}"
				lappend LineList "LINE:d$Device#$Color:$DeviceName"
			}
		}

		# Generate the graph file via the rrdgraph command
		set CmdArgs [list $Options(-file) {*}$Options(-rrd_arguments) \
		                         {*}$DefList {*}$CDefList {*}$LineList]
		::Log {Rrd graph generation: $CmdArgs} 1
		if {[catch {
			if {$RrdTclAvailable} {
				eval [list Rrd::graph {*}$CmdArgs]
			} else {
				exec rrdtool graph {*}$CmdArgs
			}
		}]} {
			::Log {RrdGraph error: ($::errorInfo)} 3
		}
	}

}; # end namespace thc_Rrd
