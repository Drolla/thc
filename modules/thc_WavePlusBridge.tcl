##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_WavePlusBridge.tcl - THC interface for Wave Plus Bridges
# 
# This module implements the interface functions for one or multiple Wave Plus 
# bridges.
#
# Copyright (C) 2020 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Wave Plus Bridge interface

# Group: Introduction and setup
#
# The thc_WavePlusBridge module implements THC devices that get data from
# Airthings Wave Plus Bridges provided at the following URL :
# <https://github.com/Drolla/WavePlus_Bridge>.
#
# The following Wave Plus sensor data is available :
#
# * temperature: Temperature in °C
# * humidity: Relative humidity in %
# * pressure: Air pressure in 
# * radon_st: Radon short-term averaged, in Bq/m3
# * radon_lt: Radon long-term averaged, in Bq/m3
# * co2: CO2 level
# * voc: VOC level
#
# To connect to a Wave Plus Bridge it needs to be declared with 
# <thc::WavePlusBridge::Init> :
# 
#    > thc::WavePlusBridge::Init AirCellarOffice 2930014021 http://192.168.1.132:80
# 
# Then, each THC device linked to a Wave Plus Bridge has to be declared with 
# <thc::DefineDevice> :
#
#    > thc::DefineDevice CellarOffice,temp \
#    >      -name "Cellar Office Temp" -group Environment -format "%.1f°C" -update 1m \
#    >      -get {thc_WavePlusBridge {"AirCellarOffice" "temperature"}}

######## z-Way device control functions ########

namespace eval ::thc::WavePlusBridge {

	variable DeviceDefinitions; # DeviceDefinitions(Name): Device definition array
	variable LastReadTime; # LastReadTime(SN): Last time the data has been read
	variable DeviceData; # DeviceData(SN,parameter>: Cached device data

	##########################
	# Proc: thc::WavePlusBridge::Configure
	#    Defines general configurations related to the Wave Plus Bridge 
	#    connections.
	#
	# Parameters:
	#    [-data_validity_time <DataValidityTime> - Data validity time in 
	#                     seconds, default=300
	#    [-min_update_period <MinUpdatePeriod> - Minimum update period in 
	#                     seconds (more recent update requests are ignored), 
	#                     default=60
	#    [-nbrtrials <NbrTrials>] - Defines the number of trials in case of 
	#                     connection timeouts. Default is 1.
	#    [-timeout <TimeoutMS>] - Option forwarded to http::geturl. Default 
	#                     is 500. Allows defining the timeout in milliseconds.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc::WavePlusBridge::Configure \
	#    >    -data_validity_time 600 -min_update_period 120
	#    
	# See also:
	#    <thc::WavePlusBridge::Init>
	##########################

	variable Config
	array set Config {
		-data_validity_time 300
		-min_update_period 60
	   -nbrtrials 1
	   -timeout 500
	}

	proc Configure {args} {
		variable Config
		
		if {$args=={}} {
			return [array get Config]
		} elseif {[llength $args]==1} {
			return $Config($args)
		} else {
			array set Config $args
		}
	}


	##########################
	# Proc: thc::WavePlusBridge::Init
	#
	# Parameters:
	#    Name - Wave Plus device name
	#    SR   - Wave Plus serial number, or the device nickname exposed by the 
	#           Wave Plus Bridge
	#    URL  - Full qualified URL to access the Wave Plus Bridge. The provided 
	#           URL needs to be composed by the 'http://' prefix, the IP address 
	#           as well as the port.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc::WavePlusBridge::Init AirCellarOffice 2930014021 http://192.168.1.132:80
	#    
	# See also:
	#    <z-Way device definitions>
	##########################

	proc Init {Name SR URL} {
		variable DeviceDefinitions
		variable LastReadTime
		set DeviceDefinitions($Name) [list $SR $URL]
		set LastReadTime($SR) 0
	}

	proc Get {GetCmdList} {
		variable Config;
		variable DeviceDefinitions
		variable LastReadTime
		variable DeviceData

		#puts "::thc::WavePlusBridge::Get \{$GetCmdList\}"

		# Create the list of Wave Plus Bridges (=URLs) to read. Ignore the ones
		# that have bee recently read (within MinUpdatePeriodSeconds seconds)
		set URLsToRead {}
		foreach GetCmd $GetCmdList {
			lassign $DeviceDefinitions([lindex $GetCmd 0]) SN URL
			if {$::thc::Time<$LastReadTime($SN)+$Config(-min_update_period)} continue
			lappend URLsToRead $URL
		}
		set URLsToRead [lsort -unique $URLsToRead]
		
		# Read all data from all Wave Plus Bridges and safe the data in the 
		# DeviceData array.
		foreach URL $URLsToRead {
			# Read the data
			catch {
				set WPBridgeRawData [::thc::GetUrl $URL -method GET \
						-nbrtrials $Config(-nbrtrials) -timeout $Config(-timeout)];
					# -> 200 OK {{"current_time": 1577891310, "devices": {"Office": {"update_time": 1577890655, "humidity": 43.5, "radon_st": 69, "radon_lt": 36, "temperature": 19.85, "pressure": 900.68, "co2": 1390.0, "voc": 465.0}, "Living": {"update_time": 1577890615, "humidity": 44.0, "radon_st": 130, "radon_lt": 41, "temperature": 19.02, "pressure": 900.1, "co2": 854.0, "voc": 1615.0}}}}
				
				# Transform the JSON response into a Tcl list construct
				regsub -all {\"(.*?)\"} $WPBridgeRawData {\1} WPBridgeRawData; # Remove surrounding quotes
					# -> 200 OK {{current_time: 1577891310, devices: {Office: {update_time: 1577890655, humidity: 43.5, radon_st: 69, radon_lt: 36, temperature: 19.85, pressure: 900.68, co2: 1390.0, voc: 465.0}, Living: {update_time: 1577890615, humidity: 44.0, radon_st: 130, radon_lt: 41, temperature: 19.02, pressure: 900.1, co2: 854.0, voc: 1615.0}}}}
				regsub -all {[:,]} $WPBridgeRawData {} WPBridgeRawData; # Remove columns and commas
					# -> 200 OK {{current_time 1577891310 devices {Office {update_time 1577890655 humidity 43.5 radon_st 69 radon_lt 36 temperature 19.85 pressure 900.68 co2 1390.0 voc 465.0} Living {update_time 1577890615 humidity 44.0 radon_st 130 radon_lt 41 temperature 19.02 pressure 900.1 co2 854.0 voc 1615.0}}}}
				
				# Ignore the result if it was not a valid HTTP response
				if {[lindex $WPBridgeRawData 0]!= "200" || [lindex $WPBridgeRawData 1]!= "OK"} continue

				# Extract current time and device sensor data.
				array set WPBridgeData [lindex $WPBridgeRawData 2 0]
				
				# Safe all valid values in the DeviceData array
				foreach {SN AllDeviceData} $WPBridgeData(devices) {
					# Ignore devices that are not requested
					if {![info exists LastReadTime($SN)]} continue
					
					# Assign the data to the DeviceData array. Check data validity
					foreach {Parameter Value} $AllDeviceData {
						if {![string is double -strict $Value]} { # Ignore if not a value
							set Value "" }
						set DeviceData($SN,$Parameter) $Value
					}
					
					# Store the last WP sensor read time (=current THC time - passed
					# seconds since the WP brige has read the sensor data)
					set LastReadTime($SN) [expr {
							$::thc::Time-$WPBridgeData(current_time)+$DeviceData($SN,update_time)}]
				}
			}
		}
		
		# Create the response value list. Ignore the Wave Plus device values that 
		# haven't been updated recently.
		set NewStates {}
		foreach GetCmd $GetCmdList {
			set SN [lindex $DeviceDefinitions([lindex $GetCmd 0]) 0]
			set Parameter [lindex $GetCmd 1]
			set Value ""
			if {$::thc::Time<$LastReadTime($SN)+$Config(-data_validity_time) &&
			    [info exists DeviceData($SN,$Parameter)]} {
				set Value $DeviceData($SN,$Parameter)
			}
			lappend NewStates $Value
		}
		
		#puts " --> $NewStates"
		return $NewStates
	}

}; # end namespace WavePlusBridge

return
