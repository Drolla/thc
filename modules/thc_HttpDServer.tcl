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
# See: http://wiki.tcl.tk/14701

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
		set Server [socket -server [namespace current]::Accept $Port]
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
			close $Server
			set Server ""
		}
	}

	##########################
	# Accept
	#    This is the connection handler that is called if a new connection is
	#    requested. It configures the channel and defines the communication 
	#    handler.
	##########################

	proc Accept {Socket Host Port} {
		Log {thc_HttpDServer: Accept $Socket $Host $Port} 2
		fconfigure $Socket -blocking 0
		fileevent $Socket readable [list [namespace current]::Handle $Socket]
	}

	##########################
	# Handle
	#    Communication Handler. This command is called on each HTTP request.
	#    It interprets the request and returns the requested data.
	##########################

	proc Handle {Socket} {
		# Check if the channel has data available
		if {[eof $Socket]} {
			# Do nothing if no data is available
			close $Socket
			return
		}

		# HTTP request parser setup
		set ContentType "text/html"; # Default content type, supported types: text/html, text/plain, "" (undefined/binary)
		set State Connecting; # HTTP request section
		set ErrorRecord {}; # Error code, list of HTTP error code and HTML error text
		
		# Start reading the available data, line after line
		while {[gets $Socket Line]>=0} {
			# Decode the HTTP request line
			if {$State=="Connecting"} {
				if {[regexp {GET /(.*) HTTP/[\d\.]+} $Line {} GetArgs]} {
					set State Header
				} else {
					set ErrorRecord {"400 bad request" "400 - Bad request"}
					break
				}
			
			# Read the header/attribute lines
			} elseif {$State=="Header"} {
				if {$Line!=""} {
					if {[regexp {^\s*([^: ]+)\s*:\s*(.*)\s*$} $Line {} AttrName AttrValue]} {
						set Attribute([string tolower $AttrName]) $AttrValue
					} else {
						# Attribute not recognized, ignore it
					}
				} else {
					set State RequestCompleted
				}
			}
		}

		# Evaluate the request if no error happened until this point. The command
		# 'GetRequestResponseData' will provide the data by modifying the 
		# variables 'Data', 'ContentType' and 'ErrorRecord'.
		if {$ErrorRecord=={}} {
			GetRequestResponseData [DecodeHttp $GetArgs]
		}
		
		# Return an error code if an error happened
		if {$ErrorRecord!={}} {
			set Data "<html><h1>[lindex $ErrorRecord 1]</h1></html>"
			if {[llength $ErrorRecord]>2} {
				append Data "<pre>[lindex $ErrorRecord 2]</pre>"}
			
			puts $Socket "HTTP/1.0 [lindex $ErrorRecord 0]"
			puts $Socket "Content-length: [string length $Data]"
			puts $Socket "Connection: close"
			puts $Socket ""
			puts $Socket $Data
		
		# ... otherwise return the requested data
		} else {
			switch -- $ContentType {
				text/html {
					regsub -all {\n} $Data "<br>\n" Data
					set Data "<html><body>$Data</body></html>"}
				text/plain {
					set Data "<html><body><pre>$Data</pre></body></html>"}
			}
			
			fconfigure $Socket -translation {auto crlf}
			puts $Socket "HTTP/1.0 200 OK"
			if {$ContentType!=""} {
				puts $Socket "Content-Type: $ContentType"}
			puts $Socket "Content-length: [string length $Data]"
			puts $Socket "Connection: close"
			puts $Socket ""
			fconfigure $Socket -translation {auto binary}
			puts $Socket $Data
		}

		# Close the socket ('connection: close')
		catch {close $Socket}
		Log {thc_HttpDServer: $Socket closed} 2
	}

	##########################
	# DecodeHttp
	#    Decode the hexadecimal encoding contained in HTTP requests (e.g. %2F).
	##########################

	proc DecodeHttp {line} {
		# Identify hex encoded sequences (%XY), and replace these sequences by 
		# corresponding ASCII characters.
		while {[regexp -indices {%[[:xdigit:]][[:xdigit:]]} $line Pos]} {
			set Char [format %c [scan [string range $line [lindex $Pos 0]+1 [lindex $Pos 1]] %x]]
			set line [string replace $line {*}$Pos $Char]
		}
		return $line
	}

	##########################
	# GetRequestResponseData
	#    Evaluates the GET request string and returns the result by modifying
	#    inside the calling procedure the variables 'Data', 'ErrorRecord' and
	#    'ContentType'
	##########################

	proc GetRequestResponseData {GetRequestString} {
		upvar 1 Data Data
		upvar 1 ContentType ContentType
		upvar 1 ErrorRecord ErrorRecord

		regexp {^([^\s]*)\s*(.*)$} $GetRequestString {} FirstWord RemainingLine
		switch -exact -- $FirstWord {
			"eval" {
				if {[catch {set Data [uplevel #0 $RemainingLine]}]} {
					set ErrorRecord [list "404 incorrect command" "404 - Incorrect command" $RemainingLine]
				}
			}
			"" -
			"help" {
				set Data "<h1>THC HTTP Debug Server</h1>\n\
				          help: this help information\n\
							 eval <TclCommand>: Evaluate a Tcl command and returns the result\n\
				          download <File>: Download a file (from a browser)\n\
				          show <File>: Show a file (in a browser)"
			}
			"download" -
			"show" {
				if {![file exists $RemainingLine]} {
					set ErrorRecord [list "404 file not found" "404 - File not found" "File '$RemainingLine' not found"]
				} else {
					set f [open $RemainingLine r]
					set Data [read $f]
					close $f
					if {$FirstWord=="download"} {
						set ContentType ""; # binary
					} else {
						set ContentType text/plain
					}
				}
			}
			"default" {
				set ErrorRecord [list "404 command unknown" "404 - Command unknown" "Command unknown: $FirstWord"]
			}
		}
	}

}; # end namespace thc_HttpDServer