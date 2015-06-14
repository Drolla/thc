##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_Web_API.tcl - Commands provided to the THC web server
# 
# This module provides all the commands available to the THC web server for THC.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Web server API
# Both components of the <Web interface>, the web server as well as the web 
# application, can be extended if necessary. This page provides developer
# information about the web server.

# Group: HTTP web server internals
#
# The web server provided by the module <Web interface> responds to *get*
# requests. It return either files or results from the commands provided 
# by the _thc_Web::API_ namespace.
#
#   * File requests: The URL has to point to an existing file inside the web 
#     home directory 'modules/thc_Web/www_simple/'. The master HTML file *index.html*
#     will be returned if the URL is an empty string. If 'gzip' encoding is
#     accepted, and an equivalent compressed file with the ending '.gz' is 
#     available, this compressed file will be returned.
#   * Command requests: If an URL starts with /api/ the tail string will be
#     considered as command that will be executed and whose result will be 
#     returned. Command and arguments have to be separated by spaces (Tcl 
#     syntax). The web server support all commands that are part of the 
#     namespace _thc_Web::API_. An initial commands set is provided by this 
#     sub module (see <Web server commands>), but it can be extended if 
#     necessary (see <Web server command set extension>).
#
# The following lines provides some command request examples. 
#
# Classic URL:
#   : 192.168.1.123/api/GetDeviceStates MyLight
#   : 
#   : localhost/api/SetDeviceState MyLight 0
#   : 
#   : 192.168.1.123/api/GetDeviceInfo
#
# Javascript/jQuery:
#   : $.get("/api/SetDeviceState "+DeviceId+" 0");
#   : 
#   : $.getJSON('/api/GetDeviceInfo', function(DevicesInfo) {
#   :    BuildGui(DevicesInfo);
#   : });
#   : 
#   : setInterval(function() {
#   :    $.ajax({
#   :       url: "/api/GetDeviceStates",
#   :       success: function(data) {
#   :          UpdateStates(data);
#   :       },
#   :       dataType: "json"});
#   :    }, 2000);

######## Web server commands ########

# Group: Web server commands
# This section provides the list of the standard web server commands. 

namespace eval thc_Web::API {

	##########################
	# Proc:  thc_Web::API::GetDeviceInfo
	#    Returns device information. GetDeviceInfo returns information about all
	#    available devices in the JSON format. The keys of the returned main 
	#    list are the device identifiers. The values are sub lists composed
	#    by device attribute names and values. The following attributes are 
	#    provided: 'name', 'type', 'group', 'format'.
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    Device information in JSON format
	#    
	# Examples (HTTP get request):
	#    > http://localhost:8080/api/GetDeviceInfo
	#    > -> {
	#    >    "Light1stFloor_state":
	#    >      {"name":"Light1stFloor","type":"switch","range":"","group":"Light","format":"%s"},
	#    >    "Temperature1stFloor_state":
  	#    >      {"name":"Temperature1stFloor","type":"level","range":"","group":"Environment","format":"%sC"},
	#    >    "Humidity1stFloor_state":
  	#    >      {"name":"Humidity1stFloor","type":"level","range":"","group":"Environment","format":"%s%%"}
	#    >    }
	##########################

	proc GetDeviceInfo {} {
		global DeviceList DeviceAttributes
		set DeviceInfoJSON "\{\n"
		foreach Device $DeviceList {
			append DeviceInfoJSON "\"$Device\":\n  \{"
			
			foreach {AttrName} {name type group data} {
				append DeviceInfoJSON "\"$AttrName\":\"$DeviceAttributes($Device,$AttrName)\","
			}
			append DeviceInfoJSON "\"range\":\[[join $DeviceAttributes($Device,range) ,]\],"
			append DeviceInfoJSON "\},\n"
		}

		append DeviceInfoJSON "\n\}"
		regsub -all {,\s*\}} $DeviceInfoJSON "\}" DeviceInfoJSON
		return [list application/json $DeviceInfoJSON]
	}

	
	##########################
	# Proc:  thc_Web::API::GetDeviceStatesAfterEvent
	#    Waits on event and returns device states. GetDeviceStatesAfterEvent
	#    waits on a change of a device state (event) and returns then the new
	#    device states in the JSON format. This returned list contains pairs of
	#    device identifiers and device states.
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    Device states in the JSON format
	#    
	# Examples (HTTP get request):
	#    > http://localhost:8080/api/GetDeviceStatesAfterEvent
	#    > -> {"Light1stFloor_state": "1", "Temperature1stFloor_state": "21.5C", 
	#    >     "Humidity1stFloor_state": "68%"}
	##########################

	proc GetDeviceStatesAfterEvent {} {
		after 60000 {set ::Event(*) 0}
		vwait ::Event(*)
		return [GetDeviceStates]
	}
	
	
	##########################
	# Proc:  thc_Web::API::GetDeviceStates
	#    Returns device states. GetDeviceStatesAfterEvent returns then the 
	#    current device states in the JSON format. This returned list contains 
	#    pairs of device identifiers and device states.
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    Device states in the JSON format
	#    
	# Examples (HTTP get request):
	#    > http://localhost:8080/api/GetDeviceStates
	#    > -> {"Light1stFloor_state": "1", "Temperature1stFloor_state": "21.5C", 
	#    >     "Humidity1stFloor_state": "68%"}
	##########################

	proc GetDeviceStates {} {
		global UpdateDeviceList State DeviceAttributes
		set DeviceStatesJSON "\{"
		foreach Device $UpdateDeviceList {
			set DeviceState $State($Device)
			catch {set DeviceState [format $DeviceAttributes($Device,format) $DeviceState]}
			append DeviceStatesJSON "\"$Device\":\"$DeviceState\","
		}
		append DeviceStatesJSON "\}"
		regsub -all {,\s*\}} $DeviceStatesJSON "\}" DeviceStatesJSON
		return [list application/json $DeviceStatesJSON]
	}

	##########################
	# Proc:  thc_Web::API::SetDeviceState
	#    Set device states. SetDeviceState sets the states of a list of devices 
	#    accordantly to a specified level.
	#
	# Parameters:
	#    DeviceId - Device identifier
	#    NewState - New state
	#
	# Returns:
	#    Device states in the JSON format
	#    
	# Examples (HTTP and jQuery get requests):
	#    > http://localhost:8080/api/SetDeviceState Light1stFloor_state 1
	#    > -> 
	#    > $.get("/api/SetDeviceState "+DeviceId+" 1");
	#    > -> 
	##########################

	proc SetDeviceState {DeviceId NewState} {
		variable DeviceStates
		variable DeviceNbr
		regsub -all {_} $DeviceId {,} DeviceId
		Set $DeviceId $NewState
		return {text/plain ""}
	}

	##########################
	# Proc:  thc_Web::API::GetDeviceData
	#    Get device data. GetDeviceData returns the data attached to a device,
	#    usually stored in an external file.
	#
	# Parameters:
	#    DeviceId - Device identifier
	#
	# Returns:
	#    Binary device data
	#    
	# Examples (HTTP and jQuery get requests):
	#    > http://localhost:8080/api/GetDeviceData Battery,1day
	#    > -> <<<Binary device data>>>
	#    > $.get("/api/GetDeviceData "+DeviceId);
	#    > -> <<<Binary device data>>>
	##########################

	proc GetDeviceData {DeviceId} {
		global DeviceAttributes
		regsub -all {_} $DeviceId {,} DeviceId

		set DeviceType $DeviceAttributes($DeviceId,type)
		set DeviceData $DeviceAttributes($DeviceId,data)

		if {$DeviceType=="image"} {
			catch {set ContentType $::thc_Web::HttpdMimeType([file extension $DeviceData])}
			return [list file $DeviceData]
		} else {
			set ReturnContent "Device type '$DeviceType' unknown!"
			return [list text/plain $ReturnContent]
		}
	}

}; # end namespace thc_Web::API


# Group: Web server command set extension
#
# The initial web server command set can be extended by defining additional 
# commands inside the namespace *thc_Web::API*. Such command definitions
# can for example be made inside the THC configuration file. The web server
# commands need to return a list with 2 elements; The first one is the HTTP
# response MIME type, the second one is the HTTP response itself.
#
#   : namespace eval thc_Web::API {
#   :    proc GetDateTime {
#   :       return [list text/plain \
#   :                    [clock format $::Time -format {%A, %Y.%m.%d, %H:%M:%S}]]
#   :    }
#   : }
#
# Instead of returning an explicit MIME type together with a raw data chunk an 
# API command can also return a list composed by the keyword 'file' and a file 
# path. The web server will in this case return the MIME type related to the 
# file extension together with the file content.
#
#   : namespace eval thc_Web::API {
#   :    proc GetLogo {
#   :       return [list file "/opt/mystuff/mylogo.gif"]
#   :    }
#   : }
#
# The web server is recognizes the following file extensions :
#
# - .txt - text/plain
# - .htm - text/html .html text/html
# - .css - text/css
# - .gif - image/gif
# - .jpg - image/jpeg
# - .png - image/png
# - .xbm - image/x-xbitmap
# - .js  - application/javascript
# - .json - application/json
# - .xml - application/xml
#
# If a file extension is not recognized the MIME type 'text/plain' is returned.
# Additional MIME types can be declared via the array variable 
# thc_Web::HttpdMimeType. Example:
#
#   : set thc_Web::HttpdMimeType(.mp4) "audio/mp4"
