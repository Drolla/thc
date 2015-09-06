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

# See: http://wiki.tcl.tk/4333
#      http://wiki.tcl.tk/11017

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
	#    port - HTTP port
	#
	# Returns:
	#    HTTP server socket identifier
	#    
	# Examples:
	#    > thc_Web::Start 8087
	##########################
	
	proc Start {port} {
		variable Server
		# Close an eventually previously opened server
		Stop
		
		# Open the new socket server
		set Server [socket -server [namespace current]::Accept $port]
		Log "thc_Web started (port $port)" 3
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
		Log {thc_Web: Accept $Socket $Host $Port} 1
		fconfigure $Socket -blocking 0
		fileevent $Socket readable "[namespace current]::Handle $Socket"
	}

	##########################
	# Handle
	#    Communication Handler. This command is called on each HTTP request.
	#    It interprets the request and returns the requested data.
	#    The data can either be a file, or data provided by a command of the
	#    thc_Web::API namespace. If a file is requested, gzip compression 
	#    accepted, and an equivalent compressed file with a .gz extension 
	#    exists, this compressed file will be returned.
	##########################

	# Set of supported MIME file types
	
	array set HttpdMimeType {
		{} text/plain
		.txt text/plain
		.htm text/html .html text/html
		.css text/css
		.gif image/gif .jpg image/jpeg .png image/png
		.xbm image/x-xbitmap
		.js application/javascript
		.json application/json
		.xml application/xml
	}
	
	# Handler implementation

	proc Handle {Socket} {
		variable HttpdMimeType
		
		Log {Handle $Socket} 1

		# Check if the channel has data available
		if {[eof $Socket]} {
			# Do nothing if no data is available
			close $Socket
			return
		}

		# Default request attributes, they are overwritten if explicitly 
		# specified in the HTTP request
		array set Attribute {
			accept "text/plain"
			accept-encoding ""
		}

		# HTTP request parser setup
		set State Connecting; # HTTP request section
		set ErrorRecord {}; # Error code, list of HTTP error code and HTML error text

		# Start reading the available data, line after line
		while {[gets $Socket Line]>=0} {
			# Decode the HTTP request line
			if {$State=="Connecting"} {
				set State Header
				if {![regexp {GET /(.*) HTTP/[\d\.]+} $Line {} GetArgs]} {
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
		
		# Return a 'bad request response in case no valid line hasn't been received
		if {$State=="Connecting"} {
			set ErrorRecord {"400 bad request" "400 - Bad request"}
		}

		# Evaluate the request if no error happened until this point. The command
		# 'GetRequestResponseData' will provide the data by modifying the 
		# variables 'Data', 'FilePath', 'ContentType' and 'ErrorRecord', 
		# 'Encoding', 'NoCache'.

		set Data ""; # Data to be returned
		set FilePath ""; # This variable will be set to the file path if the 
		                 # content of a file has to be returned. Has precedence over 'Data'.
		set Encoding ""; # Indicates that a specific encoding has to be used
		set NoCache 0; # Default cache handling: No
		set ContentType $Attribute(accept); # Default content type

		if {$ErrorRecord=={}} {
			GetRequestResponseData [DecodeHttp $GetArgs]
		}

		# Read the file content if a file has to be provided
		if {$ErrorRecord=={} && $FilePath!=""} {
			# Check if gzip encoding is accepted, and if the relevant gziped 
			# file exists
			if {[regexp {\mgzip\M} $Attribute(accept-encoding)] && [file exists $FilePath.gz]} {
				set FilePath $FilePath.gz
				set Encoding "gzip"
			}

			Log {    File: $FilePath} 1

			# Read the file content as binary data. Catch errors due to 
			# non existing files
			if {[catch {set f [open $FilePath RDONLY]} err]} {
				set ErrorRecord [list "404 file not found" "404 - File not found" "File '$FilePath' not found"]
			} else {
				fconfigure $f -translation binary
				set Data [read $f]
				close $f
			}

			# Evaluate the MIME type. If the type is not recognized the default
			# type is returned (plain text)
			catch {
				set ContentType $HttpdMimeType([file extension $FilePath])}
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
			fconfigure $Socket -translation {auto binary}
			puts $Socket $Data
		
		# ... otherwise return the requested data, together with eventual 
		# encoding and cache attributes. Handle the data as binary, the content
		#  of some files is binary (and to match also the length attribute).
		} else {
			fconfigure $Socket -translation {auto crlf}; # HTTP headers need to have crlf line breaks
			puts $Socket "HTTP/1.0 200 OK"
			if {$ContentType!=""} {
				puts $Socket "Content-Type: $ContentType"}
			if {$Encoding!=""} {
				puts $Socket "Content-Encoding: $Encoding"}
			if {$NoCache!=""} {
				puts $Socket "Cache-Control: no-cache, no-store, must-revalidate"}
			puts $Socket "Content-length: [string length $Data]"
			puts $Socket "Connection: close"
			puts $Socket ""
			fconfigure $Socket -translation {auto binary}; # Binary data to match the content length attribute
			puts $Socket $Data
		}

		# Close the socket ('connection: close')
		close $Socket
		Log {thc_HttpDServer: $Socket closed} 1
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
	#    inside the calling procedure the variables 'Data', 'FilePath', 
	#    'ErrorRecord', 'ContentType', 'Encoding', 'NoCache'
	##########################

	proc GetRequestResponseData {GetRequestString} {
		global ThcHomeDir
		upvar 1 Data Data
		upvar 1 FilePath FilePath
		upvar 1 ContentType ContentType
		upvar 1 ErrorRecord ErrorRecord
		upvar 1 Encoding Encoding
		upvar 1 NoCache ErrorRecord
		
		# Process API command GET requests
		if {[regexp {^api/(.*)$} $GetRequestString {} ApiCommand]} {
			# Extract the command and arguments
			set Args [lrange $ApiCommand 1 end]
			set ApiCommand [lindex $ApiCommand 0]

			Log {    API Command: ${ApiCommand}($Args)} 1
			
			# Execute the command. Catch eventual errors
			if {![catch {set ApiResult [thc_Web::API::$ApiCommand {*}$Args]} err]} {
				# If the MIME type is 'file', register the file path (the file 
				# will be handled later). Otherwise register the content type 
				# and data.
				if {[lindex $ApiResult 0]=="file"} {
					set FilePath [lindex $ApiResult 1]
				} else {
					set ContentType [lindex $ApiResult 0]
					set Data [encoding convertto utf-8 [lindex $ApiResult 1]]
				}
				set NoCache 1; # API data shouldn't be cached
			} else {
				# The command execution failed, return an error
				set ErrorRecord [list "404 incorrect command" "404 - Incorrect command" $GetRequestString]
			}

		# Process file GET requests
		} else {
			# Register the file. The provided file paths are relative to the 
			# directory of this present file.
			set FilePath $GetRequestString
			set FilePath "$ThcHomeDir/../modules/thc_Web/$FilePath"

			# From: $ThcHomeDir/../modules/thc_Web/www_simple/module/thc_Timer/index.html
			# To:   $ThcHomeDir/../modules/thc_Timer/thc_Web/www_simple/index.html
			regsub {thc_Web/([^/]+)/module/([^/]+)/} $FilePath {\2/thc_Web/\1/} FilePath

			# If the path corresponds to a directory add 'index.html'.
			if {[file isdirectory $FilePath]} {
				set FilePath [file join $FilePath index.html] }
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