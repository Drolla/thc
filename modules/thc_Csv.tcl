##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_Csv.tcl - THC CSV data log module
# 
# This module provides functions to log device states in the CSV format in
# a file.
#
# Copyright (C) 2017 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Status logging in CSV format

# Group: Introduction
#
# This module provides functions to log device states in the CSV format in
# a file.


######## CSV Log ########

# Group: CSV log module commands

namespace eval thc_Csv {

	variable FHandle; # CSV file handle
	variable CsvDeviceList {}; # List of devices to log
	variable LastLogTime 0; # Last logging time, used to respect the min interval
	variable MinInterval 0; # Minimum interval is ignored

	##########################
	# Proc: thc_Csv::Open
	#    Creates or opens an CSV data file. If the file exists already the new
	#    logging data will be will be appended to the file. This works also if 
	#    devices are added or removed. If the devices to are not explicitly 
	#    specified with the '-devices' option, the states of all devices are 
	#    logged.
	#
	# Parameters:
	#    -file <CsvFile> - The name of the CSV data file to open or to create
	#    [-min_interval <MinInterval>] - Minimal interval in seconds in which 
	#          the data are logged into the CSV data file. The thc_Csv::Log 
	#          command will be ignored if it is called in a shorter interval 
	#          than the specified minimum interval.
	#    [-devices <DeviceList>] - List of devices to log. By default all devices
	#          are logged.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    The following example opens or creates an CSV data file that logs the
	#    states of all devices in a minimum interval of 5 minutes :
	#
	#    > thc_Csv::Open -file /var/thc/thc.csv -min_interval 300
	#    
	# See also:
	#    <thc_Csv::Log>
	##########################

	proc Open {args} {
		global UpdateDeviceList
		variable LastLogTime 0; # Last logging time, used to respect the min interval
		variable FHandle; # CSV file handle
		variable CsvDeviceList {}; # List of devices to log
		set CsvNewDeviceList {}; # New devices that are not in the existing database
		set CsvRemovedDeviceList {}; # Devices removed from the existing database

		::Log {thc_Csv::Open: Setup the CSV data logging file} 3

		# Default options
		set DeviceList $UpdateDeviceList; # List of devices to log
		variable MinInterval 0; # Minimum interval is ignored

		# Parse all options, and check them
		for {set a 0} {$a<[llength $args]} {incr a} {
			set arg [lindex $args $a]
			switch -- $arg {
				-file {
					set CsvFile [lindex $args [incr a]] }
				-min_interval {
					set MinInterval [lindex $args [incr a]] }
				-devices {
					set DeviceList [lindex $args [incr a]] }
				default {
					Assert 1 "thc_Csv::Open: Option '-$arg' is unknown!" }
			}
		}
		Assert [info exists CsvFile] "thc_Csv::Open: Option '-file' is mandatory!"
		Assert [string is integer -strict $MinInterval] "thc_Csv::Open: Option '-min_interval' has to be an integer!"

		# If the CSV file exists already: Read the list of the devices from the 1st line
		if {[file exists $CsvFile]} {
			::Log { -> Use current file} 3
			
			# Read the first line, trim white spices at the line end
			set FHandle [open $CsvFile r+]
			gets $FHandle CsvLine
			set CsvLine [string trim $CsvLine]
			
			# Obtain the list of devices. The device names are separated by commas 
			# (,). Device names may be placed in double quotes ("), especially if 
			# they contain commas.
			# Split the first line into sub-strings at the location of commas.
			# Concatenate the sub-strings if they start with a double quote and if
			# the obtained string is not ending with a double quote.
			set Device ""
			set Separator ""
			foreach Item [lrange [split $CsvLine ","] 1 end-1] {
				append Device $Separator $Item
				set Separator ","
				# Register the new device if the name doesn't start with a double 
				# quote, or if it starts and ends with a double quote
				if {[string index $Device 0]!="\"" || [string index $Device end]=="\""} {
					# Remove eventual sourounding double quotes
					set Device [string trim $Device "\""]
					# Add a dummy device ("") if the device doesn't exists anymore
					if {[lsearch $DeviceList $Device]<0} {
						lappend CsvRemovedDeviceList $Device }
					lappend CsvDeviceList $Device
					set Device ""
					set Separator ""
				}
			}
		} else {
			::Log { -> Create new file} 3
			set FHandle [open $CsvFile w]
		}
		
		# Add new devices that are not yet declared in an existing CSV file
		foreach Device $DeviceList {
			if {[lsearch $CsvDeviceList $Device]<0} {
				lappend CsvNewDeviceList $Device
				lappend CsvDeviceList $Device
			}
		}

		# Inform about not anymore used devices
		if {$CsvRemovedDeviceList!={}} {
			::Log { -> Not anymore used devices: $CsvRemovedDeviceList} 3
		}

		# If new devices are present: Create the entire 1st CSV line, reserve
		# 2048 characters (for eventual further additional devices)
		if {[llength $CsvNewDeviceList]>0} {
			::Log { -> Adding new devices: $CsvNewDeviceList} 3
			set CsvLine "Date/Time,"
			# Add double quotes if the device name contain commas
			foreach Device $CsvDeviceList {
				if {[regexp {,} $Device]} {
					set Device "\"$Device\"" }
				append CsvLine $Device ","
			}
			set CsvLine "$CsvLine[string repeat { } [expr 2048-[string length $CsvLine]]]"

			# Write the 1st CSV line on the file beginning
			seek $FHandle 0
			puts $FHandle $CsvLine
			flush $FHandle
		}

		# Add the logging data to the file end
		seek $FHandle 0 end
		return
	}


	##########################
	# Proc: thc_Csv::Log
	#    Logs the devices states. The states of all declared devices is written 
	#    to the opened CSV data file.
	#
	#    For devices that have a sticky state, this sticky state is written 
	#    instead of the instantaneous state. The sticky states has usually to 
	#    be cleared with <ResetStickyStates> after having logged them by 
	#    thc_Csv::Log.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_Csv::Log; ResetStickyStates
	#    
	# See also:
	#    <thc_Csv::Open>, <ResetStickyStates>
	##########################

	proc Log {} {
		global Time State StickyState
		variable CsvDeviceList
		variable MinInterval
		variable LastLogTime
		variable FHandle

		# Ignore the logging request if no CSV file exists or if the minimum
		# time interval is not respected.
		if {![info exists FHandle]} return
		if {$MinInterval>0 && $Time<$LastLogTime+$MinInterval} return
		set LastLogTime $Time

		# Log the state of each device. If a state is not defined report ''. Log
		# the sticky state if existing.
		variable CsvDeviceList
		set StateLine "$Time,"
		foreach Device $CsvDeviceList {
			set Value ""
			catch { # Ignore devices that have been removed
				set Value [expr $State($Device)]
				set Value [expr $StickyState($Device)]; # Use the sticky state if existing
			}
			append StateLine "$Value,"
		}

		# Add the device states to the CSV data file
		::Log {Csv::Log $StateLine} 1
		if {[catch {
			puts $FHandle $StateLine
			flush $FHandle
		}]} {
			::Log {Csv::Log error: ($::errorInfo)} 3
		}
	}

}; # end namespace thc_Csv
