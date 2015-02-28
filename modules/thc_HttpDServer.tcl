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
# This module provides a tiny HTTP server that allows taking control over the 
# THC server, for example for debugging purposes. This HTTP debug server allows 
# running Tcl commands on the HTC server, getting device states, getting files, 
# etc. Once the HTTP debug server is started (see <thc_HttpDServer::Start>),
# it accepts the following HTTP requests:
#
#   help - Provides help
#   eval - Evaluates a Tcl command sequence
#
# The HTTP requests can directly be performed from a web browser, or they can 
# be issued by applications. Examples for HTTP requests:
#
#   > http://192.168.1.21:8085/help
#   > -> help: this help information
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
# The HTTP debug server accepts only a single HTTP connection at a time. It 
# doesn't provide any security or authentication and should therefore be 
# disabled in an insecure environment.

######## Http Access Server ########
# See: http://wiki.tcl.tk/14701

namespace eval thc_HttpDServer {
	namespace export Start Stop

	variable TimeOut [expr 15*60*1000]; # Timeout in milliseonds (15 minutes)

	variable Script ""
	variable Server ""
	variable Socket ""
	variable TimeOutHandle "";

	proc UpdateTimeOut {} {
		variable TimeOut
		variable TimeOutHandle
		if {$TimeOut!=""} {
			catch {after cancel $TimeOutHandle}
			set TimeOutHandle [after $TimeOut [namespace current]::TimeOut]
		}
	}

	##########################
	# Proc: thc_HttpDServer::Start
	#    Start the HTTP server. This command starts an HTTP server at the 
	#    specified port. It accepts Tcl commands and scripts, evaluates them, 
	#    and returns the result.
	#
	# Parameters:
	#    port - HTTP port
	#
	# Returns:
	#    HTTP server socket identifier
	#    
	# Examples:
	#    > thc_HttpDServer::Start 8085
	##########################
	
	proc Start {port} {
		variable Socket
		variable Server
		if {$Socket ne "" || $Server ne ""} Stop
		set Server [socket -server [namespace current]::Accept $port]
	}
	
	proc TimeOut {} {
		variable Socket
		Log "thc_HttpDServer: Connection timed out" 2
		CloseSocket
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
			CloseSocket
			close $Server
			set Server ""
		}
	}

	proc CloseSocket {} {
		variable Socket
		variable TimeOutHandle

		catch {close $Socket}
		set Socket ""

		# Delete the timeout handle
		catch {after cancel $TimeOutHandle}
		set TimeOutHandle ""

		Log {thc_HttpDServer: $Socket closed} 2
	}

	proc Accept {sock host port} {
		variable Socket
		Log {thc_HttpDServer: Accept $sock $host $port} 2
		fconfigure $sock -blocking 0 -buffering none
		if {$Socket ne ""} {
			Log "thc_HttpDServer: Cannot accept more than one connection at a time!" 1
			close $sock
		} else {
			set Socket $sock
			variable Script ""
			fileevent $sock readable [namespace current]::Handle
			UpdateTimeOut
		}
	}

	proc Handle {} {
		variable Script
		variable Socket

		if {[eof $Socket]} {
			CloseSocket
			return
		}

		if {![catch {read $Socket} chunk]} {
			append Script $chunk
			regexp -line {^(.*)$} $Script {} FirstLine

			if {$FirstLine eq "bye"} {
				puts $Socket "Bye!"
				CloseSocket
				return
			}
			
			if {[regexp {GET /(.*) HTTP/1.1} $FirstLine {} Path]} {
				set Path [DecodeHttp $Path]
				regexp {^([^\s]*)\s*(.*)$} $Path {} FirstWord RemainingLine
				switch -exact -- $FirstWord {
					"eval" {
						if {[catch {set Result [uplevel #0 $RemainingLine]}]} {
							puts $Socket "Error: $::errorInfo"
						} else {
							puts $Socket $Result
						}
					}
					"help" {
						puts $Socket "help: this help information"
						puts $Socket "eval <TclCommand>: Evaluate a Tcl command and returns the result"
						puts $Socket "download <File>: Download a file (from a browser)"
						puts $Socket "show <File>: Show a file (in a browser)"
					}
					"download" -
					"show" {
						if {![file exists $RemainingLine]} {
							puts $Socket "HTTP/1.1 404 file not found"
							puts $Socket ""
							puts $Socket "<html><h1>404 file '$RemainingLine' not found</h1></html>"
						} else {
							puts $Socket "HTTP/1.1 200 OK"
							puts $Socket ""
							set f [open $RemainingLine r]
							set FileContent [read $f]
							close $f
							if {$FirstWord=="download"} {
								puts $Socket $FileContent
							} else {
								puts $Socket "<html><head></head><body><pre>$FileContent</pre></body></html>"
							}
						}
					}
					"default" {
						puts $Socket "HTTP/1.1 404 command unknown"
						puts $Socket ""
						puts $Socket "<html><h1>404</h1></html>"
					}
				}

				set Script ""
				CloseSocket
				return
			}
			
			if {[info complete $Script]} {
				catch {uplevel "#0" $Script} result
				if {$result ne ""} {
					puts $Socket $result
				}
				set Script ""
				UpdateTimeOut
			}
		} else {
			CloseSocket
		}
	}

	proc DecodeHttp {line} {
		while {[regexp -indices {%[[:xdigit:]][[:xdigit:]]} $line Pos]} {
			set Char [format %c [scan [string range $line [lindex $Pos 0]+1 [lindex $Pos 1]] %x]]
			set line [string replace $line {*}$Pos $Char]
		}
		return $line
	}
}; # end namespace thc_HttpDServer