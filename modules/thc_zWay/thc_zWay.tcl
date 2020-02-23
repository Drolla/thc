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
#   - Initialize the interface with the <thc::zWay::Init> command. For z-Way 
#     revision 2.1.1 and above you need to provide the name and password of 
#     a user registered by the z-Way server.
#   - Declare the Z-Wave devices with <thc::DefineDevice>, see <z-Way device definitions>
#
# Once this setup is completed the declared Z-Wave devices are accessible via 
# the global <thc::Get> and <thc::Set> commands.

# Topic: z-Way device definitions
#    z-Way devices are defined with the global <thc::DefineDevice> command. The 
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
#    TagReader - Provides info about the last event of the BeNEXT tag reader.
#                The <thc::Get> command returns a list of 2-3 elements. The first 
#                one corresponds to the last event time, the second one is one 
#                of the following event names: 'lock', 'unlock', 'tamper', 
#                'wrongcode'. In case the event is 'wrongcode' the 3rd element 
#                corresponds to this wrong code.
#    SwitchMultiBinary - Groups multiple binary switch instances of a device to
#                        a multi-bit instance. The device identifier requires 3
#                        elements: Device number, instance number with the 
#                        lower index, instance number with the higher index.
#    Control - Allows implementing control states (=variables) on the z-Way server.
#    
# Examples:
#    > thc::zWay::Init "http://192.168.1.21:8083" -user admain -password admin
#    >
#    > thc::DefineDevice Surveillance,state -get {thc_zWay "Virtual DummyDevice_bn_5"} \
#    >                                      -set {thc_zWay "Virtual DummyDevice_bn_5"}
#    > 
#    > thc::DefineDevice LightCellar,state    -get {thc_zWay "SwitchBinary 20.1"} \
#    >                                      -set {thc_zWay "SwitchBinary 20.1"}
#    > 
#    > thc::DefineDevice LightLiv2,state    -type level \
#    >                                      -get {thc_zWay "SwitchMultilevel 12.2"} \
#    >                                      -set {thc_zWay "SwitchMultilevel 12.2"}
#    > 
#    > thc::DefineDevice Sirene,state       -get {thc_zWay "SwitchBinary 16.0"} \
#    >                                      -set {thc_zWay "SwitchBinary 16.0"}
#    > thc::DefineDevice Sirene,battery     -get {thc_zWay "Battery 16.0"} -update 1h
#    > 
#    > thc::DefineDevice TagReader1,state   -get {thc_zWay "TagReader 22"} \
#    >                                      -set {thc_zWay "SwitchBinary 22"}
#    > thc::DefineDevice TagReader1,battery -get {thc_zWay "Battery 22"} -update 1h
#    > 
#    > thc::DefineDevice MultiCellar,temp     -get {thc_zWay "SensorMultilevel 23.0.1"} -update 1m
#    > thc::DefineDevice MultiCellar,hum      -get {thc_zWay "SensorMultilevel 23.0.5"} -update 1m
#    > thc::DefineDevice MultiCellar,battery  -get {thc_zWay "Battery 23"} -update 1h
#    > 
#    > thc::DefineDevice FourLevelFan,state -get {thc_zWay "SwitchMultiBinary 33.1.2"} \
#    >                                      -set {thc_zWay "SwitchMultiBinary 33.1.2"}

######## z-Way device control functions ########

namespace eval ::thc::zWay {

	variable UrlBase ""; # URL used to access the z-Way server
	variable GetUrlArgs {}; # Optional GetUrl headers (e.g. used for authentication (cookies))
	variable InitArgs {}

	##########################
	# Proc: thc::zWay::Init
	#    Initializes the z-Way/Razberry interface. Init waits first until the 
	#    z-Way server is accessible, and loads then the THC extension to the z-Way
	#    JavaScript interpreter.
	#
	#    z-Way 2.1.1 and above requires authentication. The user name and password 
	#    of a user registered by the z-Way server needs to be provided.
	#
	#    Init needs to be called before any z-Way devices are declared.
	#
	# Parameters:
	#    URL - Full qualified URL to access the z-Way server. The provided URL 
	#          needs to be composed by the 'http://' prefix, the IP address as 
	#          well as the port.
	#    [-user <UserName>] - User name for authentication (z-Way 2.1.1 or above)
	#    [-password <UserName>] - Password for authentication (z-Way 2.1.1 or above)
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc::zWay::Init "http://192.168.1.21:8083" -user admain -password admin
	#    
	# See also:
	#    <z-Way device definitions>
	##########################

	proc Init {Url args} {
		variable UrlBase ""
		variable GetUrlArgs {}
		variable InitArgs

		# Avoid bug with http 2.8.9 and Tcl8.6(.4) related to the deflate 
		# compression (http://core.tcl.tk/tcl/info/b9d0434667d94e5f)
		if {[package vsatisfies [package provide Tcl] 8.6-8.6.5] && 
		    [package vsatisfies [package provide http] 2.8-2.8.10]} {
			set GetUrlArgs [list -headers [list Accept-Encoding "gzip"]]
		}
		
		array set ArgsArray $args
		::thc::Log {Open z-Way connection on $Url} 3

		# Wait until the z-Way server can be accessed, access the base path
		while {1} {
			if {![catch {
				::thc::GetUrl "$Url" -method HEAD -validate 1 -noerror 0 -nbrtrials 1 {*}$GetUrlArgs
			}]} {
				break
			}
			
			::thc::Log {  z-Way controller not accessible on $Url, try again in 30'} 3
			after 30000
		}

		# Check if authentication is required
		set zWayRevResponse [::thc::GetUrl "$Url/JS/Run/zway.controller.data.softwareRevisionVersion.value" -method GET -noerror 0 {*}$GetUrlArgs]
		if {[lindex $zWayRevResponse 0]>=400 && [lindex $zWayRevResponse 0]<500} { # 4xx error
			::thc::Log {  Unexpected z-Way server response ($zWayRevResponse), try using authentication} 3
			if {![info exists ArgsArray(-user)] || ![info exists ArgsArray(-password)]} {
				::thc::Log {  No user name/password defined! Call: thc::zWay::Init -user <User> -password <PW>} 3
				return
			}

			# Login with the user name and password
			set tok [http::geturl "$Url/ZAutomation/api/v1/login" -method POST \
			            -type application/json {*}$GetUrlArgs \
			            -query "\{\"form\": true, \"login\": \"$ArgsArray(-user)\", \"password\": \"$ArgsArray(-password)\", \"keepme\": false, \"default_ui\": 1\}" ]
			set StatusCode [http::ncode $tok]
			set Status [http::code $tok]
			set Meta [http::meta $tok]
			http::cleanup $tok

			if {$StatusCode!=200} {
				::thc::Log {  Authentication failed, z-Way interface will be disabled ($Status)} 3
				return
			}
			
			# Get the cookie, raise an error if no cookie has been provided
			foreach {n v} $Meta {
				if {$n=="Set-Cookie"} {
					lappend Cookies [lindex [split $v {;}] 0] }
			}
			if {![info exists Cookies]} {
				::thc::Log {  Unable to login, no authentication cookie provided. z-Way interface will be disabled!} 3
				return
			}
			
			# Add the authentication info (cookie) to the header line 
			set GetUrlArgs [list -headers [concat [lindex $GetUrlArgs 1] Cookie [join $Cookies {;}]]]
			
			# Try again to read the z-Way revision
			set zWayRevResponse [::thc::GetUrl "$Url/JS/Run/zway.controller.data.softwareRevisionVersion.value" -method GET -noerror 0 {*}$GetUrlArgs]
			if {[lindex $zWayRevResponse 0]!=200} {
				::thc::Log {  Unable to communicate with the z-Way server response ($zWayRevResponse), z-Way interface will be disabled!} 3
				return
			}
		}
		::thc::Log {  z-Way software revision is: [lindex $zWayRevResponse 2]} 2

		# Assure that the THC extension has been loaded to the z-Way server. The
		# command 'Get_IndexArray' will be executed:
		#    http://<Url>/JS/Run/Get_IndexArray(8.1);
		# If the THC extension is correctly loaded the following result will be
		# returned:
		#    -> [8,1,0]
		# Otherwise, f the THC extension is not loaded the following error is
		# obtained:
		#    z-Way 1.x: Error 500: Internal Server Error
		#    z-Way 2.x: ReferenceError: Get_IndexArray is not defined
		# The THC extension is loaded with the executeFile command:
		#    http://<Url>/JS/Run/executeFile("thc_zWay.js");
		if {![catch {
			set CheckResResponse [::thc::GetUrl "$Url/JS/Run/Get_IndexArray(257.1)" -method GET {*}$GetUrlArgs -noerror 0]; # -> [257,1,0]
		}] && [lindex $CheckResResponse 2]=={[257,1,0]}} {
			::thc::Log {  z-Way THC extensions are available} 3
			set InitArgs $args
			set UrlBase $Url
			return
		}

		# The THC extension seems not be loaded. Load it, and check again if
		# it has been correctly loaded.
		if {![catch {
			set StatusResponse [::thc::GetUrl "$Url/JS/Run/executeFile(\"thc_zWay.js\");" -method GET {*}$GetUrlArgs -noerror 0]; # -> Null
			set CheckResResponse [::thc::GetUrl "$Url/JS/Run/Get_IndexArray(257.1)" -method GET {*}$GetUrlArgs -noerror 0]; # -> [257,1,0]
		}] && [lindex $CheckResResponse 2]=={[257,1,0]}} {
			::thc::Log {  Loaded z-Way THC extension} 3
			set InitArgs $args
			set UrlBase $Url
		} else {
			::thc::Log {  Cannot load z-Way THC extension! Is it placed inside the automation folder? z-Way module is disabled.} 3
		}
	}

	##########################
	# thc::zWay::ReInit
	#    Re-initializes the z-Way/Razberry interface using the arguments
	#    previously provided to thc::zWay::Init. thc::zWay::ReInit is called
	#    by thc::zWay::Get and thc::zWay::Set if they receive the response 401 
	#    (Unauthorized).
	##########################

	proc ReInit {} {
		variable UrlBase
		variable InitArgs
		::thc::Log "thc::zWay::ReInit - Reinitialize the zWay connection" 2
		Init $UrlBase {*}$InitArgs
	}
	
	##########################
	# DeviceSetup
	# Is called by DefineDevice each time a new z-Way device is declared.
	##########################

	proc DeviceSetup {GetCmd} {
		variable UrlBase
		variable GetUrlArgs
		
		# Ignore the device definition if the z-Way server is not accessible:
		if {$UrlBase==""} return
		
		set CommandGroup [lindex $GetCmd 0]
		set DeviceNbr [lindex $GetCmd 1]
		switch $CommandGroup {
			"TagReader" {
				# Install the bindings for the alarms
				::thc::Log {thc::zWay::DeviceSetup $DeviceNbr -> Configure TagReader} 1
				set Response [::thc::GetUrl "$UrlBase/JS/Run/Configure_TagReader($DeviceNbr)" -method GET {*}$GetUrlArgs] }
		}
	}

	proc Get {GetCmdList} {
		variable UrlBase
		variable GetUrlArgs
		set NbrDevices [llength $GetCmdList]
		
		# Return empty states if the z-Way server is not accessible:
		if {$UrlBase==""} {
			return [lrepeat $NbrDevices ""] }; # -> {"" "" "" ...}

		set JsonFormatedArgs $GetCmdList; # -> {SensorBinary 12} {SensorBinary 5} {SwitchBinary 7.2}
		regsub -all "\\\{" $JsonFormatedArgs "\[\"" JsonFormatedArgs
		regsub -all "\\\}" $JsonFormatedArgs "\"\]" JsonFormatedArgs
		regsub -all "\\\] \\\[" $JsonFormatedArgs "\],\[" JsonFormatedArgs
		regsub -all { } $JsonFormatedArgs "\",\"" JsonFormatedArgs; # -> ["SensorBinary","12"],["SensorBinary","5"],["SwitchBinary","7.2"]
		set JsonFormatedArgs "\[$JsonFormatedArgs\]"; # -> [["SensorBinary","12"],["SensorBinary","5"],["SwitchBinary","7.2"]]
		
		set NewStateResponse [::thc::GetUrl "$UrlBase/JS/Run/Get($JsonFormatedArgs)" -method GET {*}$GetUrlArgs]; # -> [0,"",1,[1407694169,"unlock"],\"\",17.7]

		# Return empty states if the z-Way server response isn't OK (200)
		if {[lindex $NewStateResponse 0]!=200} {
			::thc::Log "thc::zWay::Get: $UrlBase/JS/Run/Get returned [lindex $NewStateResponse 0], [lindex $NewStateResponse 1]" 2
			# Reinitialize zWay for the next time
			if {[lindex $NewStateResponse 0]==401} {
				ReInit }
			return [lrepeat $NbrDevices ""] }
		set NewStateResult [lindex $NewStateResponse 2]

		regsub -all {\\"} $NewStateResult {"} NewStateResult; # -> [0,"",1,[1407694169,"unlock"],"",17.7]. This substitution is required starting with z-way 2.0.1 (not necessary for 2.0.1-rc6)
		regsub -all {^\"(.+)\"$} $NewStateResult {\1} NewStateResult; # Remove surrounding quotes
		regsub -all "\\\[" $NewStateResult "\{" NewStateResult
		regsub -all "\\\]" $NewStateResult "\}" NewStateResult
		regsub -all "," $NewStateResult { } NewStateResult; # -> {0 "" 1 {1407694169  "unlock"} \"\" 17.7}
		regsub -all {\\{0,3}\"(\w+)\\{0,3}\"} $NewStateResult {\1} NewStateResult; # -> {0 "" 1 {1407694169  unlock } "" 17.7}
		set NewStateResult [lindex $NewStateResult 0]; # -> 0 0 1 {1407694169  unlock } 33 17.7
		
		return $NewStateResult
	}

	proc Set {SetCmdList NewState} {
		variable UrlBase
		variable GetUrlArgs
		set NbrDevices [llength $SetCmdList]
		
		# Return empty states if the z-Way server is not accessible:
		if {$UrlBase==""} {
			return [lrepeat $NbrDevices ""] }; # -> {"" "" "" ...}

		set JsonFormatedArgs $SetCmdList; # -> {Control Surveillance} {SwitchBinary 20.1}
		regsub -all "\\\{" $JsonFormatedArgs "\[\"" JsonFormatedArgs
		regsub -all "\\\}" $JsonFormatedArgs "\"\]" JsonFormatedArgs
		regsub -all "\\\] \\\[" $JsonFormatedArgs "\],\[" JsonFormatedArgs
		regsub -all { } $JsonFormatedArgs "\",\"" JsonFormatedArgs; # -> ["Control","Surveillance"],["SwitchBinary","20.1"]
		set JsonFormatedArgs "\[$JsonFormatedArgs\]"; # -> [["Control","Surveillance"],["SwitchBinary","20.1"]]
		
		set NewStateResponse [::thc::GetUrl "$UrlBase/JS/Run/Set($JsonFormatedArgs,$NewState)" -method GET {*}$GetUrlArgs]
		# Return empty states if the z-Way server response isn't OK (200)
		if {[lindex $NewStateResponse 0]!=200} {
			::thc::Log "thc::zWay::Set: $UrlBase/JS/Run/Set returned [lindex $NewStateResponse 0], [lindex $NewStateResponse 1]" 2
			# Reinitialize zWay for the next time
			if {[lindex $NewStateResponse 0]==401} {
				ReInit }
			return [lrepeat $NbrDevices ""] }
		set NewStateResult [lindex $NewStateResponse 2]

		regsub -all {^\"(.+)\"$} $NewStateResult {\1} NewStateResult; # Remove surrounding quotes
		regsub -all "\\\[" $NewStateResult "\{" NewStateResult
		regsub -all "\\\]" $NewStateResult "\}" NewStateResult
		regsub -all "\[,\"\]" $NewStateResult { } NewStateResult; # -> {0 0} "
		set NewStateResult [lindex $NewStateResult 0]; # -> 0 0
		
		return $NewStateResult
	}

	proc Sleep {ElementList} {
		variable UrlBase
		variable GetUrlArgs
		set DeviceId $::thc::DeviceId
		
		# Ignore this command if the z-Way URL isn't defined
		if {$UrlBase==""} return

		foreach Element $ElementList {
			lappend ElementIdList $DeviceId($Element)
		}
		::thc::GetUrl $UrlBase/JS/Run/Sleep(\[$ElementIdList\]) -method GET {*}$GetUrlArgs
	}

}; # end namespace thc_zWay

return
