##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_Web.tcl - THC web interface
# 
# This module provides a web interface for THC.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: Web interface

# Group: Overview
#
# This module provides a simple but complete web interface for THC. To enable 
# the interface it needs to be initiated with the command <thc_Web::Start>.
#
# The web interface adds to THC a HTTP web server and provides a web
# application. Both the web application and the web server can be extended 
# if necessary (see <Web server API>). 

######## Web Interface Http Access Server ########

package require t2ws

proc t2ws::WriteLog {Message Tag} {
	::Log "t2ws: $Message" 3
}

# Group: Commands

namespace eval thc_Web {
	namespace export Start Stop

	# Module variables
	variable Server ""; # Server handler

	##########################
	# Proc: thc_Web::Start
	#    Starts the HTTP server. This command starts an HTTP web server at the 
	#    specified port.
	#
	# Parameters:
	#    Port - HTTP port
	#
	# Returns:
	#    HTTP server socket identifier
	#    
	# Examples:
	#    > thc_Web::Start 8087
	##########################
	
	proc Start {Port} {
		variable Server
		# Close an eventually previously opened server
		Stop
		
		# Open the new socket server
		set Server [t2ws::Start $Port -responder [namespace current]::GetRequestResponseData -method GET]
		Log "thc_Web started (port $Port)" 3
	}
	
	
	##########################
	# Proc: thc_Web::Stop
	#    Closes a running HTTP web server.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_Web::Stop
	##########################

	proc Stop {} {
		variable Server
		# Stop the server if it is still running
		if {$Server ne ""} {
			Log "thc_Web stopped" 3
			t2ws::Stop $Server
			set Server ""
		}
	}


	##########################
	# GetRequestResponseData
	#    Evaluates the GET request string and returns the result by modifying
	#    inside the calling procedure the variables 'Data', 'FilePath', 
	#    'ErrorRecord', 'ContentType', 'Encoding', 'NoCache'
	##########################

	proc GetRequestResponseData {Request} {
		global ThcHomeDir
		set GetRequestString [dict get $Request URI]
		Log {GetRequestResponseData $GetRequestString} 1
		
		# Process API command GET requests
		if {[regexp {^/api/(.*)$} $GetRequestString {} ApiCommand]} {
			# Extract the command and arguments
			set Args [lrange $ApiCommand 1 end]
			set ApiCommand [lindex $ApiCommand 0]

			# Execute the command. Catch eventual errors
			if {![catch {set ApiResult [thc_Web::API::$ApiCommand {*}$Args]} err]} {
				# If the MIME type is 'file', return the file path (the file 
				# will be handled later). Otherwise return the content type 
				# and data.
				if {[lindex $ApiResult 0]=="file"} {
					return [dict create File [lindex $ApiResult 1] NoCache 1]
				} else {
					set ContentType [lindex $ApiResult 0]
					set Body [encoding convertto utf-8 [lindex $ApiResult 1]]
					return [dict create Body $Body ContentType $ContentType NoCache 1]
				}
				set NoCache 1; # API data shouldn't be cached
			} else {
				# The command execution failed, return an error
				return [dict create Status "404" Body "404 - Incorrect command: $GetRequestString"]
			}

		# Process file GET requests
		} else {
			# Register the file. The provided file paths are relative to the 
			# directory of this present file.
			set FilePath "$ThcHomeDir/../modules/thc_Web${GetRequestString}"

			# From: $ThcHomeDir/../modules/thc_Web/www_simple/module/thc_Timer/index.html
			# To:   $ThcHomeDir/../modules/thc_Timer/thc_Web/www_simple/index.html
			regsub {thc_Web/([^/]+)/module/([^/]+)/} $FilePath {\2/thc_Web/\1/} FilePath

			# If the path corresponds to a directory add 'index.html'.
			if {[file isdirectory $FilePath]} {
				set FilePath [file join $FilePath index.html] }

			return [dict create File $FilePath]
		}
	}

}; # end namespace thc_Web


# Load the main API commands
source $::ThcHomeDir/../modules/thc_Web/thc_Web_API.tcl

# Load the API commands from the other modules
foreach WebAPIFile [glob -nocomplain $::ThcHomeDir/../modules/*/thc_Web/thc_Web_API.tcl] {
	source $WebAPIFile
}
unset -nocomplain WebAPIFile