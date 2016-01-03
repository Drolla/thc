##########################################################################
# THC - Tight Home Control
##########################################################################
# thc_HttpDServer.tcl - THC HTTP Debug Server module
# 
# This module implements a tiny HTTP server that allows taking control over the  
# THC server via an HTTP port, for example for debugging purposes. 
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: HTTP debug server
# This module provides a tiny HTTP 1.0 server that allows taking control over the 
# THC server, for example for debugging purposes. This HTTP debug server allows 
# running Tcl commands on the THC server, getting device states, getting files, 
# etc. Once the HTTP debug server is started (see <thc_HttpDServer::Start>),
# it accepts the following HTTP requests:
#
#   help - Provides help
#   eval - Evaluates a Tcl command sequence
#   download - Download a file
#   show - Show a file (HTML rendered)
#
# The HTTP requests can directly be performed from a web browser, or they can 
# be issued by applications. Examples for HTTP requests:
#
#   > http://192.168.1.21:8085/help
#   > -> help: This help information
#   > -> eval <TclCommand>: Evaluate a Tcl command and returns the result
#   > -> download <File>: Download a file (from a browser)
#   > -> show <File>: Show a file (in a browser)
#
#   > http://192.168.1.21:8085/eval array get State
#   > -> MotionSalon,state 0 Light2nd,state 0 MultiSalon,temp 19.5 MultiSalon,battery 60
#
#   > http://192.168.1.21:8085/eval JobsString
#   > -> 45s:RrdLog   45s:U_1m      2m:RrdGph1D 42m:RrdGph1W 42m:U_1h     15h:EvalSun  16h:RrdGph1M
#
#   > http://192.168.1.21:8085/file /var/thc/thc.log
#   > -> ...
#
# The HTTP debug server uses the HTTP protocol 1.0. It 
# doesn't provide any security or authentication and should therefore be 
# disabled in an insecure environment.

######## Http Access Server ########

package require t2ws

namespace eval thc_HttpDServer {
	namespace export Start Stop

	# Module variables
	variable Server ""; # Server handler

	##########################
	# Proc: thc_HttpDServer::Start
	#    Start the HTTP server. This command starts an HTTP server at the 
	#    specified port. It accepts Tcl commands, evaluates them, 
	#    and returns the result.
	#
	# Parameters:
	#    Port - HTTP port
	#
	# Returns:
	#    HTTP server socket identifier
	#    
	# Examples:
	#    > thc_HttpDServer::Start 8085
	##########################
	
	proc Start {Port} {
		variable Server
		Stop
		set Server [t2ws::Start $Port [namespace current]::GetRequestResponseData GET]
		Log "thc Debug server started (port $Port)" 3
	}
	
	##########################
	# Proc: thc_HttpDServer::Stop
	#    Closes a running HTTP server.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > thc_HttpDServer::Stop
	##########################

	proc Stop {} {
		variable Server
		if {$Server ne ""} {
			Log "thc Debug server stopped" 3
			t2ws::Stop $Server
			set Server ""
		}
	}


	##########################
	# GetRequestResponseData
	#    Evaluates the GET request string and returns the result by modifying
	#    inside the calling procedure the variables 'Data', 'ErrorRecord' and
	#    'ContentType'
	##########################

	proc GetRequestResponseData {Request} {
		set GetRequestString [dict get $Request URI]

		regexp {^([^\s]*)\s*(.*)$} $GetRequestString {} FirstWord RemainingLine
		switch -exact -- $FirstWord {
			"eval" {
				if {[catch {set Data [uplevel #0 $RemainingLine]}]} {
					return [dict create Status "404" Body "404 - Incorrect Tcl command: $RemainingLine"]
				}
				return [dict create Body $Data]
			}
			"" -
			"help" {
				set Data "<h1>THC HTTP Debug Server</h1>\n\
				          help: this help information<br>\n\
							 eval <TclCommand>: Evaluate a Tcl command and returns the result<br>\n\
				          download <File>: Download a file (from a browser)<br>\n\
				          show <File>: Show a file (in a browser)"
				return [dict create Body $Data ContentType .html]
			}
			"download" {
				return [dict create File $RemainingLine ContentType "" Header [dict create Content-Disposition "attachment; filename=\"[file tail $RemainingLine]\""]]
			}
			"show" {
				return [dict create File $RemainingLine ContentType  "text/plain"]
			}
			"default" {
				return [dict create Status "404" Body "404 - Unknown command: $FirstWord"]
			}
		}
	}

}; # end namespace thc_HttpDServer