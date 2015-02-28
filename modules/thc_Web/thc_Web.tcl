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
	#    requested. It configures the channel and defines a communication 
	#    handler.
	##########################
	
	proc Accept {Channel Host Port} {
		Log {thc_Web: Accept $Channel $Host $Port} 1
		fconfigure $Channel -blocking 0 -buffering none
		fileevent $Channel readable "[namespace current]::Handle $Channel"
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

	proc Handle {Channel} {
		global ThcHomeDir
		variable HttpdMimeType
		
		Log {Handle $Channel} 1
		
		# Check if the channel has data available
		if {[eof $Channel]} {
			# Do nothing if no data is available

		# Read the available data from the channel, and process them
		} elseif {![catch {read $Channel} chunk]} {
			Log {[regsub -all -- "\n" "Handle $Channel:\n$chunk\n" "\n   "]} 1

			# Default request attributes, they are overwritten if explicitly 
			# specified in the HTTP request
			set ContentType "text/plain"
			set AcceptEncoding ""
			
			# Extract form the HTTP request data the request line and eventually
			# provided attributes
			regexp -line {^(.*)$} $chunk {} RequestLine
			regexp -line {^Accept:\s*([^\s,]+)} $chunk {} ContentType
			regexp -line {^Accept-Encoding:\s*(.*)$} $chunk {} AcceptEncoding
			
			# Helper variables, default values
			set Error 0; # Non-zero indicates an error
			set Encoding ""; # Another value defines an encoding
			set NoCache 0; # Default cache handling: No
			set FilePath ""; # If non "" the file content will be returned
			
			# Process API command GET requests
			if {[regexp {GET /api/(.*) HTTP/1.1} $RequestLine {} ApiCommand]} {
				# Decode the command line and extract the command and arguments
				set ApiCommand [DecodeHttp $ApiCommand]
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
						set ReturnContent [encoding convertto utf-8 [lindex $ApiResult 1]]
					}
					set NoCache 1; # API data should be cached
				} else {
					# The command execution failed, return an error
					set Error 1
				}

			# Process file GET requests
			} elseif {[regexp {GET /(.*) HTTP/1.1} $RequestLine {} FilePath]} {
				# Register the file. If the path is undefined the default main HTTP
				# file will be returned. The provided file paths are relative to 
				# the directory of this present file.
				set FilePath [DecodeHttp $FilePath]
				if {$FilePath==""} {
					set FilePath "index.html"
				}

				set FilePath "$ThcHomeDir/../modules/thc_Web/$FilePath"

				# From: $ThcHomeDir/../modules/thc_Web/www_simple/module/thc_Timer/index.html
				# To:   $ThcHomeDir/../modules/thc_Timer/thc_Web/www_simple/index.html
				regsub {thc_Web/([^/]+)/module/([^/]+)/} $FilePath {\2/thc_Web/\1/} FilePath

			# All other requests are not supported
			} else {
				set Error 1
			}
				
			# Handle files
			if {$FilePath!=""} {
				# Check if gzip encoding is accepted, and if the relevant gziped 
				# file exists
				if {[regexp {\mgzip\M} $AcceptEncoding] && [file exists $FilePath.gz]} {
					set FilePath $FilePath.gz
					set Encoding "gzip"
				}

				Log {    File: $FilePath} 1

				# Read the file content as binary data. Catch errors due to 
				# non existing files
				if {[catch {set f [open $FilePath RDONLY]} err]} {
					set Error 1
				} else {
					fconfigure $f -translation binary
					set ReturnContent [read $f]
					close $f
				}

				# Evaluate the MIME type. If the type is not recognized the default
				# type is returned (plain text)
				catch {set ContentType $HttpdMimeType([file extension $FilePath])}
			}
			
			# Return the result. If a failure happened a 404-page not found 
			# response will be provided. Catch failures due to broken channels
			if {[catch {
				
				# A failure happened - return the 404-not found response
				if {$Error} {
					Log {    -> Failure $Channel} 1
					puts $Channel "HTTP/1.0 404 Not Found"
					puts $Channel "Content-Type: text/html"
					puts $Channel ""
					puts $Channel "<html><head><title><No such URL.></title></head>"
					puts $Channel "<body><center>"
					puts $Channel "The URL you requested does not exist."
					puts $Channel "</center></body></html>"

				# Return the data, together with eventual encoding and cache 
				# attributes. Handle the data as binary, the content of some files
				# is binary.
				} else {
					#Log {    -> Delivered $Channel} 1
					puts $Channel "HTTP/1.0 200 OK"
					puts $Channel "Content-Type: $ContentType"
					if {$Encoding!=""} {
						puts $Channel "Content-Encoding: $Encoding"
					}
					if {$NoCache!=""} {
						puts $Channel "Cache-Control: no-cache, no-store, must-revalidate"
					}
					puts $Channel ""
					fconfigure $Channel -translation binary
					puts $Channel $ReturnContent
				}

			# The channel couldn't be written
			}]} {
				Log {    -> Error writing to $Channel, Request: $chunk} 1
			}
		}
		catch {close $Channel}
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

}; # end namespace thc_Web


# Load the main API commands
source $::ThcHomeDir/../modules/thc_Web/thc_Web_API.tcl

# Load the API commands from the other modules
foreach WebAPIFile [glob -nocomplain $::ThcHomeDir/../modules/*/thc_Web/thc_Web_API.tcl] {
	source $WebAPIFile
}
unset -nocomplain WebAPIFile