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
# This module provides a HTTP server that provides debugging features, like 
# running Tcl commands on the THC server, getting device states, getting 
# files, etc. There features are accessible by accessing via a web browser the
# port opened by this HTTP server.
#
# The HTTP debug server uses the HTTP protocol 1.0. It 
# doesn't provide any security or authentication and should therefore be 
# disabled in an insecure environment.

######## Http Access Server ########

package require t2ws

proc t2ws::WriteLog {Message Tag} {
	::Log "t2ws: $Message" 3
}

namespace eval thc_HttpDServer {
	namespace export Start Stop

	# Module variables
	variable Server ""; # Server handler
	variable ThisModuleDir [file normalize [file dirname [info script]]]

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
		set Server [t2ws::Start $Port]
		t2ws::DefineRoute $Server [namespace current]::Responder_GetFile -method GET -uri /*
		t2ws::DefineRoute $Server [namespace current]::Responder_ShowFile -method GET -uri /showfile/*
		t2ws::DefineRoute $Server [namespace current]::Responder_DownloadFile -method GET -uri /download/*
		t2ws::DefineRoute $Server [namespace current]::Responder_TclCmd -method POST -uri /*
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
	# Responder commands
	##########################

	# String2Json writes a string in JSON format (see http://json.org/)

   variable JsonMaps [list \
		"\"" "\\\"" \\ \\\\ / \\/ \b \\b \
		\f \\f \n \\n \r \\r \t \\t \
		\x00 \\u0000 \x01 \\u0001 \x02 \\u0002 \x03 \\u0003 \
		\x04 \\u0004 \x05 \\u0005 \x06 \\u0006 \x07 \\u0007 \
		\x0b \\u000b \x0e \\u000e \x0f \\u000f \x10 \\u0010 \
		\x11 \\u0011 \x12 \\u0012 \x13 \\u0013 \x14 \\u0014 \
		\x15 \\u0015 \x16 \\u0016 \x17 \\u0017 \x18 \\u0018 \
		\x19 \\u0019 \x1a \\u001a \x1b \\u001b \x1c \\u001c \
		\x1d \\u001d \x1e \\u001e \x1f \\u001f \x7f \\u007f ]

	proc String2Json {Str} {
		variable JsonMaps
		return [string map $JsonMaps $Str]
	}

	# Responder command that executes a Tcl command

	proc Responder_TclCmd {Request} {
		set TclCmd [dict get $Request Body]
		
		variable Return
		array set Return {
			Status 200
			Result ""
			Error ""
			StdOut ""
			StdErr ""
		}
		
		if {![info complete $TclCmd]} {
			set Return(Status) 406
			set Return(Result) "406 - Incomplete command"
		} else {
			interp alias {} ::puts {} [namespace current]::Puts
			set Err [catch [list uplevel #0 $TclCmd] Return(Result)]
			interp alias {} ::puts {} [namespace current]::PutsOrig
			if {$Err} {
				set Return(Error) $::errorInfo
				set Return(Result) ""
			}
		}
		
		set    Body "\{\n"
		append Body "  \"result\" : \"[String2Json $Return(Result)]\",\n"
		append Body "  \"error\" : \"[String2Json $Return(Error)]\",\n"
		append Body "  \"stdout\" : \"[String2Json $Return(StdOut)]\",\n"
		append Body "  \"stderr\" : \"[String2Json $Return(StdErr)]\"\n"
		append Body "\}"
		
		return [dict create Status $Return(Status) Body $Body]
	}

	# The next responder command extracts from the request URI a File name, that 
	# will be returned to the T2WS web server. The file server will return to 
	# the client the file content.

	proc Responder_GetFile {Request} {
		variable ThisModuleDir
		set File [dict get $Request URITail]
		if {$File==""} {
			set File "TclConsole.html"}
		return [dict create File [file join $ThisModuleDir $File]]
	}

	proc Responder_ShowFile {Request} {
		variable ThisModuleDir
		set File [dict get $Request URITail]
		return [dict create File $File ContentType "text/plain"]
	}

	proc Responder_DownloadFile {Request} {
		variable ThisModuleDir
		set File [dict get $Request URITail]
		return [dict create File $File ContentType "" Header [dict create Content-Disposition "attachment; filename=\"$File\""]]
	}

	##########################
	# Customization of 'puts'
	##########################

	# Derived from http://wiki.tcl.tk/14701 (that is itself derived from tkcon)

	proc Puts args {
		variable Return
		set NbrArgs [llength $args]
		foreach {arg1 arg2 arg3} $args { break }
	
		switch $NbrArgs {
			1 {
				append Return(StdOut) "$arg1\n"
			}
			2 {
				switch -- $arg1 {
					-nonewline {
						append Return(StdOut) $arg2 }
					stdout {
						append Return(StdOut) "$arg2\n" }
					stderr {
						append Return(StdErr) "$arg2\n" }
					default {
						set NbrArgs 0 }
				}
			}
			3 {
				if {$arg1=="-nonewline" && $arg2=="stdout"} {
					append Return(StdOut) $arg3
				} elseif {$arg1=="-nonewline" && $arg2=="stderr"} {
					append Return(StdErr) $arg3
				} elseif {$arg3=="-nonewline" && $arg1=="stdout"} {
					append Return(StdOut) $arg2
				} elseif {$arg3=="-nonewline" && $arg1=="stderr"} {
					append Return(StdErr) $arg2
				} else {
					set NbrArgs 0
				}
			}
			default {
				set NbrArgs 0
			}
		}
		## $NbrArgs == 0 means it wasn't handled above.
		if {$NbrArgs == 0} {
			global errorCode errorInfo
			if {[catch [PutsOrig {*}$args] msg]} {
				return -code error $msg
			}
			return $msg
		}
	}
	
	if {[info procs [namespace current]::PutsOrig]=={}} {
		rename ::puts [namespace current]::PutsOrig
	}
	interp alias {} ::puts {} [namespace current]::PutsOrig

}; # end namespace thc_HttpDServer