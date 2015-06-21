##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_zWay.tcl - THC interface for z-Way/Razberry
# 
# This module implements the interface functions for the z-Way/Razberry Z-Wave
# controller.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: z-Way/Razberry interface

# Group: Setup, configuration and initialization

# Topic: z-Way interface setup
# The thc_zWay module implements the interface to the z-Way/Razberry Z-Wave 
# controller. To include Z-Wave devices controlled via z-Way/Razberry, the 
# following setup needs to be performed.
#
# *z-Way server setup*
#    - The z-Way server needs to be installed and running on the target system.
#    - The Z-Wave devices need to be included into the Z-Wave network controlled 
#      by the z-Way server.
#    - The THC-z-Way interface script (thc_zWay.js, see <z-Way extension for THC>) 
#      needs to be stored in the z-Way automation directory.
#
# *THC server setup*
#   - The THC server needs to be installed and running on the target system.
#
# *THC configuration (config.tcl)*
#   - Initialize the interface with the <thc_zWay::Init> command
#   - Declare the Z-Wave devices with <DefineDevice>, see <z-Way device definitions>
#
# Once this setup is completed the declared Z-Wave devices are accessible via 
# the global <Get> and <Set> commands.

# Topic: z-Way device definitions
#    z-Way devices are defined with the global <DefineDevice> command. The 
#    'Set' and 'Get' command specifiers need to be composed in the following
#    way:
#
#    > {thc_zWay {<zWaveCommandGroup> <DeviceIdentifyer>}}
#
# The device identifier is provided by the z-Way configuration utility. The
# identifier is composed by the device number, the instance number, and the
# data record. All numbers are separated by a dot (.).
#
# The zWaveCommandGroup is provided by the Z-Wave device documentation. The 
# following command groups are supported by the thc_zWay interface module:
#
#    - SwitchBinary
#    - SensorBinary
#    - Battery
#    - SensorMultilevel
#    - SwitchMultilevel
#
# In addition to the standard Z-Wave command groups the thc_zWay interface
# provides some convenience command groups:
# 
#    Virtual - Allows accessing virtual devices from the z-way automation 
#              system.
#    TagReader - Provides info about the last event of the BeNEXT tag 
#                reader. The <Get> command returns a list of 2-3 elements. 
#                The first one corresponds to the last event time, the 
#                second one is one of the following event names: 'lock', 
#                'unlock', 'tamper', 'wrongcode'. In case the event is 
#                'wrongcode' the 3rd element corresponds to this wrong
#                code.
#    Control - Allows implementing control states (=variables) on the z-Way server.
#    
# Examples:
#    > DefineDevice Surveillance,state -get {thc_zWay "Virtual DummyDevice_bn_5"} \
#    >                                 -set {thc_zWay "Virtual DummyDevice_bn_5"}
#    > 
#    > DefineDevice LightCave,state    -get {thc_zWay "SwitchBinary 20.1"} \
#    >                                 -set {thc_zWay "SwitchBinary 20.1"}
#    > 
#    > DefineDevice LightLiv2,state    -type level \
#    >                                 -get {thc_zWay "SwitchMultilevel 12.2"} \
#    >                                 -set {thc_zWay "SwitchMultilevel 12.2"}
#    > 
#    > DefineDevice Sirene,state       -get {thc_zWay "SwitchBinary 16.0"} \
#    >                                 -set {thc_zWay "SwitchBinary 16.0"}
#    > DefineDevice Sirene,battery     -get {thc_zWay "Battery 16.0"} -update 1h
#    > 
#    > DefineDevice TagReader1,state   -get {thc_zWay "TagReader 22"} \
#    >                                 -set {thc_zWay "SwitchBinary 22"}
#    > DefineDevice TagReader1,battery -get {thc_zWay "Battery 22"} -update 1h
#    > 
#    > DefineDevice MultiCave,temp     -get {thc_zWay "SensorMultilevel 23.0.1"} -update 1m
#    > DefineDevice MultiCave,hum      -get {thc_zWay "SensorMultilevel 23.0.5"} -update 1m
#    > DefineDevice MultiCave,battery  -get {thc_zWay "Battery 23"} -update 1h

######## z-Way device control functions ########

namespace eval thc_zWay {

	variable UrlBase ""; # URL used to access the z-Way server

	##########################
	# Proc: thc_zWay::Init
	#    Initializes the z-Way/Razberry interface. Init waits first until the 
	#    z-Way server is accessible, and loads then the THC extension to the z-Way
	#    JavaScript interpreter.
	#    Init needs to be called before any z-Way devices are declared.
	#
	# Parameters:
	#    URL - Full qualified URL to access the z-Way server. The provided URL 
	#          needs to be composed by the 'http://' prefix, the IP address as 
	#          well as the port.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_zWay::Init "http://192.168.1.21:8083"
	#    
	# See also:
	#    <z-Way device definitions>
	##########################

	proc Init {Url} {
		variable UrlBase $Url
		Log {Open z-Way connection on $Url} 3

		# Wait until the z-Way server can be accessed
		while {1} {
			if {[catch {
				set zWayRev [GetUrl "$Url/JS/Run/zway.controller.data.softwareRevisionVersion.value" 0]
			}]} {
				Log {  z-Way controller not accessible on $Url, try again in 30'} 3
				after 30000
			} else {
				Log {  z-Way software revision is: $zWayRev} 2
				break
			}
		}
		
		# Assure that the THC extension has been loaded to the z-Way server. The
		# command 'Get_IndexArray' will be executed:
		#    http://192.168.1.21:8083/JS/Run/Get_IndexArray(8.1);
		# If the THC extension is correctly loaded the following result will be
		# returned:
		#    -> [8,1,0]
		# Otherwise, f the THC extension is not loaded the following error is
		# obtained:
		#    z-Way 1.x: Error 500: Internal Server Error
		#    z-Way 2.x: ReferenceError: Get_IndexArray is not defined
		# The THC extension is loaded with the executeFile command:
		#    http://192.168.1.21:8083/JS/Run/executeFile("thc_zWay.js");
		if {![catch {
			set CheckRes [GetUrl "$Url/JS/Run/Get_IndexArray(257.1)" 0]; # -> [257,1,0]
		}] && $CheckRes=={[257,1,0]}} {
			Log {  z-Way THC extensions are available} 3
			return
		}

		# The THC extension seems not be loaded. Load it, and check again if
		# it has been correctly loaded.
		if {![catch {
			set Status [GetUrl "$Url/JS/Run/executeFile(\"thc_zWay.js\");" 0]; # -> Null
			set CheckRes [GetUrl "$Url/JS/Run/Get_IndexArray(257.1)" 0]; # -> [257,1,0]
		}] && $CheckRes=={[257,1,0]}} {
			Log {  Loaded z-Way THC extension} 3
		} else {
			Log {  Cannot load z-Way THC extension! Is it placed inside the automation folder? z-Way module is disabled.} 3
			set UrlBase ""
		}
	}
	
	##########################
	# DeviceSetup
	# Is called by DefineDevice each time a new z-Way device is declared.
	##########################

	proc DeviceSetup {GetCmd} {
		variable UrlBase
		
		# Ignore the device definition if the z-Way server is not accessible:
		if {$UrlBase==""} return
		
		set CommandGroup [lindex $GetCmd 0]
		set DeviceNbr [lindex $GetCmd 1]
		switch $CommandGroup {
			"TagReader" {
				# Install the bindings for the alarms
				Log {thc_zWay::DeviceSetup $DeviceNbr -> Configure TagReader} 1
				set Result [GetUrl "$UrlBase/JS/Run/Configure_TagReader($DeviceNbr)"] }
		}
	}

	proc Get {GetCmdList} {
		variable UrlBase
		set NbrDevices [llength $GetCmdList]
		#Log "    thc_zWay::Get $GetCmdList -> OK"
		#puts "thc_zWay::Get \{$GetCmdList\}"
		
		# Return empty states if the z-Way server is not accessible:
		if {$UrlBase==""} {
			return [split [string repeat "x" [expr {$NbrDevices-1}]] "x"]; # -> {"" "" "" ...}
		}

		set JsonFormatedArgs $GetCmdList; # -> {SensorBinary 12} {SensorBinary 5} {SwitchBinary 7.2}
		regsub -all "\\\{" $JsonFormatedArgs "\[\"" JsonFormatedArgs
		regsub -all "\\\}" $JsonFormatedArgs "\"\]" JsonFormatedArgs
		regsub -all "\\\] \\\[" $JsonFormatedArgs "\],\[" JsonFormatedArgs
		regsub -all { } $JsonFormatedArgs "\",\"" JsonFormatedArgs; # -> ["SensorBinary","12"],["SensorBinary","5"],["SwitchBinary","7.2"]
		set JsonFormatedArgs "\[$JsonFormatedArgs\]"; # -> [["SensorBinary","12"],["SensorBinary","5"],["SwitchBinary","7.2"]]
		#puts "GetUrl $UrlBase/JS/Run/Get($JsonFormatedArgs)"
		
		set NewStateResult [GetUrl "$UrlBase/JS/Run/Get($JsonFormatedArgs)"]; # -> [0,0,1,[1407694169,"unlock"],33,17.7]
		#Log "$JsonFormatedArgs -> $NewStateResult"

		regsub -all {^\"(.+)\"$} $NewStateResult {\1} NewStateResult; # Remove surrounding quotes
		regsub -all "\\\[" $NewStateResult "\{" NewStateResult
		regsub -all "\\\]" $NewStateResult "\}" NewStateResult
		regsub -all "," $NewStateResult { } NewStateResult; # -> {0 0 1 {1407694169  unlock } 33 17.7}
		regsub -all {\"(\w+)\"} $NewStateResult {\1} NewStateResult; # -> {0 0 1 {1407694169  unlock } 33 17.7}
		set NewStateResult [lindex $NewStateResult 0]; # -> 0 0 1 {1407694169  unlock } 33 17.7
		
		return $NewStateResult
	}

	proc Set {SetCmdList NewState} {
		variable UrlBase
		#Log "    thc_zWay::Set \{$SetCmdList\} $NewState -> OK"
		#puts "thc_zWay::Set \{$SetCmdList\} $NewState"
		
		# Return empty states if the z-Way server is not accessible:
		if {$UrlBase==""} {
			return [split [string repeat "x" [expr [llength $GetCmdList]-1]] "x"]; # -> {"" "" "" ...}
		}

		set JsonFormatedArgs $SetCmdList; # -> {Control Surveillance} {SwitchBinary 20.1}
		regsub -all "\\\{" $JsonFormatedArgs "\[\"" JsonFormatedArgs
		regsub -all "\\\}" $JsonFormatedArgs "\"\]" JsonFormatedArgs
		regsub -all "\\\] \\\[" $JsonFormatedArgs "\],\[" JsonFormatedArgs
		regsub -all { } $JsonFormatedArgs "\",\"" JsonFormatedArgs; # -> ["Control","Surveillance"],["SwitchBinary","20.1"]
		set JsonFormatedArgs "\[$JsonFormatedArgs\]"; # -> [["Control","Surveillance"],["SwitchBinary","20.1"]]
		#puts "GetUrl $UrlBase/JS/Run/Set($JsonFormatedArgs,$NewState)"
		
		set NewStateResult [GetUrl "$UrlBase/JS/Run/Set($JsonFormatedArgs,$NewState)"]

		regsub -all {^\"(.+)\"$} $NewStateResult {\1} NewStateResult; # Remove surrounding quotes
		regsub -all "\\\[" $NewStateResult "\{" NewStateResult
		regsub -all "\\\]" $NewStateResult "\}" NewStateResult
		regsub -all "\[,\"\]" $NewStateResult { } NewStateResult; # -> {0 0} "
		set NewStateResult [lindex $NewStateResult 0]; # -> 0 0
		
		return $NewStateResult
	}

	proc Sleep {ElementList} {
		variable UrlBase
		global DeviceId
		
		# Ignore this command if the z-Way URL isn't defined
		if {$UrlBase==""} return

		foreach Element $ElementList {
			lappend ElementIdList $DeviceId($Element)
		}
		GetUrl $UrlBase/JS/Run/Sleep(\[$ElementIdList\])
	}

}; # end namespace thc_zWay
