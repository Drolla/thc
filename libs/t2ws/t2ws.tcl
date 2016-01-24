##########################################################################
# T2WS - Tiny Tcl Web Server
##########################################################################
# t2ws.tcl - Tiny HTTP Server main file
# 
# This file implements a tiny HTTP server.
#
# Copyright (C) 2016 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: T2WS - Tiny Tcl Web Server
#
# T2WS is a small HTTP server that is easily deployable and embeddable in a 
# Tcl application. To add a T2WS web server to a Tcl application, load the T2WS 
# package and start the HTTP server for the desired port (e.g. 8085) :
#
#    > package require t2ws
#    > t2ws::Start 8085 ::MyResponder
#
# The T2WS web server requires an application specific responder command that
# provides the adequate responses to the HTTP requests. The HTTP request data
# are provided to the responder command in form of a dictionary, and the T2WS
# web server expects to get back from the responder command the response also
# in form of a dictionary. The following lines implements a responder command
# example. It allows either executing Tcl command lines and returns their 
# results, or tells to the T2WS server to send files.
#
#    > proc MyResponder {Request} {
#    >    regexp {^([^\s]*)\s*(.*)$} [dict get $Request URI] {} Target ReqLine
#    >    switch -exact -- $Target {
#    >       "eval" {
#    >          if {[catch {set Data [uplevel #0 $ReqLine]}]} {
#    >             return [dict create Status "405" Body "405 - Incorrect Tcl command: $ReqLine"] }
#    >          return [dict create Body $Data ContentType "text/plain"]
#    >       }
#    >       "file" {
#    >          return [dict create File $ReqLine]
#    >       }
#    >    }
#    >    return [dict create Status "404" Body "404 - Unknown command: $ReqLine"]
#    > }
#
# More information about starting T2WS servers, stopping them, and assigning 
# responder commands are provided in section <Main API commands>. Details about
# the way the responder commands are working are provided in section 
# <The responder command>.


# Package namespace declaration

	package require Tcl 8.5

	namespace eval t2ws {}


# Group: Main API commands
#    The following group of commands is usually sufficient to deploy a web
#    server.
	
	##########################
	# Proc: t2ws::Start
	#    Starts a T2WS server. This command starts a T2WS HTTP web server at 
	#    the specified port. It returns the specified port.
	#
	#    Optionally, a responder command can be specified that is either applied 
	#    for all HTTP request methods (GET, POST, ...) and all request URIs, or 
	#    for a specific request method and URI. Additional responder commands 
	#    for other request methods and/or URIs can be specified later with 
	#    <t2ws::DefineRoute>.
	#
	# Parameters:
	#    <Port> - HTTP port
	#    [Responder] - Responder command, optional
	#    [Method] - HTTP request method glob matching pattern, default="*"
	#    [URI] - HTTP request URI glob matching pattern, default="*"
	#
	# Returns:
	#    HTTP port (used as T2WS server identifier)
	#    
	# Examples:
	#    > set MyServ [t2ws::Start $Port ::Responder_GetGeneral GET]
	#    
	# See also:
	#    <t2ws::DefineRoute>, <t2ws::Stop>
	##########################
	
	proc t2ws::Start {Port {ResponderCommand ""} {Method "*"} {URI "*"}} {
		variable Server
		Stop $Port
		Log {HttpServer::Start $Port} info 1
		dict set Server $Port [socket -server [namespace current]::Accept $Port]

		# Define the default responder command, and if defined the custom command
		DefineRoute $Port t2ws::DefaultResponderCommand "*" "*"
		if {$ResponderCommand!=""} {
			DefineRoute $Port $ResponderCommand $Method $URI }

		return $Port
	}
	
	
	##########################
	# Proc: t2ws::Stop
	#    Stops one or multiple T2WS servers. If no port is provided all running 
	#    T2WS servers are stopped, otherwise only the one specified by the 
	#    provided port.
	#
	# Parameters:
	#    [Ports] - HTTP ports of the T2WS server that have to be stopped
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::Stop $MyServ
	#    
	# See also:
	#    <t2ws::Start>
	##########################
	
	proc t2ws::Stop {{Ports ""}} {
		variable Server
		variable Responder
		
		# Get the list of open ports if no port is defined
		if {$Ports==""} {
			set Ports [dict keys $Server] }
		
		# Close the selected ports, unset the related variables
		foreach Port $Ports {
			if {[dict exists $Server $Port]} {
				Log {HttpServer::Stop $Port} info 1
				close [dict get $Server $Port]
				dict unset Server $Port
				dict unset Responder $Port }
		}
	}


	##########################
	# Proc: t2ws::DefineRoute
	#    Defines a responder command. The arguments 'Method' and 'URI' allow 
	#    applying the specified responder command for a specific HTTP request
	#    method (GET, POST, ...) and for specific request URIs.
	#
	# Parameters:
	#    <Port> - HTTP port
	#    <Responder> - Responder command
	#    [Method] - HTTP request method glob matching pattern, default="*"
	#    [URI] - HTTP request URI glob matching pattern, default="*"
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::DefineRoute $MyServ ::Responder_GetApi GET api/*
	#    
	# See also:
	#    <t2ws::Start>
	##########################

	proc t2ws::DefineRoute {Port ResponderCommand {Method "*"} {URI "*"}} {
		variable Server
		variable Responder
		if {![dict exists $Server $Port]} {
			error "No server for port $Port defined" }
		
		# Add the new responder command to the list of the related port, and sort 
		# it afterwards.
		dict lappend Responder $Port [list [string toupper $Method] $URI $ResponderCommand]
		dict set Responder $Port [lsort -index 1 -unique -decreasing [dict get $Responder $Port]]
	}


# Group: The responder command
#    The T2WS web server calls each HTTP request a responder command that has 
#    to be provided by the application. This responder command receives the 
#    entire HTTP request data in form of a dictionary, and it has to provide 
#    back to the server the HTTP response data again in form of another 
#    dictionary.
#
# Responder command setup:
#
#    <t2ws::Start> in combination with <t2ws::DefineRoute> allow specifying 
#    different responder commands for different HTTP request methods and URIs. 
#    The T2WS web server selects the target responder command by trying to 
#    match the HTTP request method and URI with the method and URI patterns 
#    that have been defined together with the responder commands. Complexer 
#    method and URI patterns are tried to be matched first and simpler patterns 
#    later. The responder command definition order is therefore irrelevant.
#    The following line contain some responder command definition examples :
#
#    > set MyServ [t2ws::Start $Port ::Responder_General * *]
#    > t2ws::DefineRoute $MyServ ::Responder_GetApi GET api/*
#    > t2ws::DefineRoute $MyServ ::Responder_GetApiPriv GET api/privat/*
#    > t2ws::DefineRoute $MyServ ::Responder_GetFile GET file/*
#
# Request data dictionary:
#
#    The responder command receives all HTTP request data in form of a 
#    dictionary that contains the following elements :
#
#       Method - Request method in upper case (e.g. GET, POST, ...)
#       URI - Request URI, without leading '/'
#       Header - Request header data, formed itself as dictionary using as keys 
#                the header field names in lower case
#       Body - Request body, binary data
#
# Response data dictionary:
#
#    The responder command returns the response data to the server in form of 
#    a dictionary. All elements of this dictionary are optional. The main 
#    elements are :
#
#        Status - Either a known HTTP status code (e.g. '404'), a known HTTP 
#                 status message (e.g. 'Not Found') or a custom status string 
#                 (e.g. '404 File Not Found'). The default status value is 
#                 '200 OK'. See <t2ws::DefineStatusCode> and 
#                 <t2ws::GetStatusCode> for the HTTP status code and message 
#                 definitions.
#        Body   - HTTP response body, binary encoded. The default body data is 
#                 an empty string.
#        Header - Custom HTTP response headers fields, case sensitive (!). The 
#                 header element is itself a dictionary that can specify 
#                 multiple header fields.
#
#    The following auxiliary elements of the response dictionary are 
#    recognized by the T2WS server :
#     
#        Content-Type - For convenience reasons the content type can directly 
#                       be specified with this element instead of the 
#                       corresponding header field.
#        File         - If this element is defined the content of the file is 
#                       read by the T2WS web server and sent as HTTP response 
#                       body to the client.
#        NoCache      - If the value of this element is true (e.g. 1) the HTTP 
#                       client is informed that the data is volatile (by 
#                       sending the header field: Cache-Control: no-cache, 
#                       no-store, must-revalidate).
#
# Examples of responder commands:
#
#    The following responder command returns simply the HTTP status 404. It can 
#    be defined to respond to invalid requests.
#
#    > proc t2ws::Responder_General {Request} {
#    >    return [dict create Status "404"]
#    > }
#
#    The next responder command extracts from the request URI a Tcl command. 
#    This one will be executed and the result returned in the respond body.
#
#    > proc t2ws::Responder_GetApi {Request} {
#    >    if {![regexp {^api/(.*)$} [dict get $Request URI] {} TclScript]} {
#    >       return [dict create Status "500" Body "500 - Tcl command cannot be extracted from '$URI'"] }
#    >    if {[catch {set Result [uplevel #0 $TclScript]} {
#    >       return [dict create Status "405" Body "405 - Incorrect Tcl command: $TclScript"] }
#    >    return [dict create Body $Result]
#    > }
#
#    The next responder command extracts from the request URI a File name, that 
#    will be returned to the T2WS web server. The file server will return to 
#    the client the file content.
#
#    > proc t2ws::Responder_GetFile {Request} {
#    >    if {![regexp {^file/(.*)$} [dict get $Request URI] {} File]} {
#    >       return [dict create Status "500" Body "File cannot be extracted from '$URI'"] }
#    >    return [dict create File $File]
#    > }
#
#    Rather than creating multiple responder commands for different targets it 
#    is also possible to create a single one that handles all the different 
#    requests.
#
#    > proc Responder_General {Request} {
#    >    regexp {^([^\s]*)\s*(.*)$} [dict get $Request URI] {} Target ReqLine
#    >    switch -exact -- $Target {
#    >       "" -
#    >       "help" {
#    >          set Data "<h1>THC HTTP Debug Server</h1>\n\
#    >                    help: this help information<br>\n\
#    >                    eval <TclCommand>: Evaluate a Tcl command and returns the result<br>\n\
#    >                    file/show <File>: Get file content<br>\n\
#    >                    download <File>: Get file content (force download in a browser)"
#    >          return [dict create Body $Data ContentType .html]
#    >       }
#    >       "eval" {
#    >          if {[catch {set Data [uplevel #0 $ReqLine]}]} {
#    >             return [dict create Status "405" Body "405 - Incorrect Tcl command: $ReqLine"] }
#    >          return [dict create Body $Data]
#    >       }
#    >       "file" - "show" {
#    >          return [dict create File $ReqLine ContentType "text/plain"]
#    >       }
#    >       "download" {
#    >          return [dict create File $ReqLine ContentType "" Header [dict create Content-Disposition "attachment; filename=\"[file tail $ReqLine]\""]]
#    >       }
#    >       "default" {
#    >          return [dict create Status "404" Body "404 - Unknown command: $ReqLine"]
#    >       }
#    >    }
#    > }


# Group: Configuration and customization
#    The following group of commands allows configuring and customizing T2WS to 
#    application specific needs.

	##########################
	# Proc: t2ws::Configure
	#    Set and get T2WS configuration options. This command can be called in 
	#    3 different ways :
	#
	#       t2ws::Configure - Returns the currently defined T2WS configuration
	#       t2ws::Configure <Option> - Returns the value of the provided option
	#       t2ws::Configure <Option/Value pairs> - Define options with new values
	#
	#    The following options are supported :
	#
	#       -protocol - Forced response protocol. Has to be 'HTTP/1.0' or 
	#                   'HTTP/1.1'
	#       -default_Content-Type - Default content type if it is not explicitly 
	#                   specified by the responder command or if it cannot be 
	#                   derived from the file extension
	#       -log_level - Log level, 0: no log, 1 (default): T2WS server 
	#                   start/stop logged, 2: transaction starts are logged, 
	#                   3: full HTTP transfer is logged.
	#
	# Parameters:
	#    [Option1] - Configuration option 1
	#    [Value1]  - Configuration value 1
	#    ...       - Additional option/value pairs can follow
	#
	# Returns:
	#    Configuration options (if the command is called in way 1 or 2)
	#    
	# Examples:
	#    > t2ws::Configure
	#    > -> -protocol {} -default_Content-Type text/plain -log_level 1
	#    > t2ws::Configure -default_Content-Type
	#    > -> text/plain
	#    > t2ws::Configure -default_Content-Type text/html
	##########################

	proc t2ws::Configure {args} {
		variable Config
		
		# No arguments are provided, return the full configuration dictionary
		if {[llength $args]==0} {
			return $Config
		
		# A single option is provided with no value, return the option value
		} elseif {[llength $args]==1} {
			if {[dict exist $Config $args]} {
				return [dict get $Config $args]
			} else {
				error "'$args' is not known configuration attribute. Valid keys are: [dict keys $Config]"
			}

		# Otherwise, create an error if element and values are not provided in pairs
		} elseif {[llength $args]%2!=0} {
			error "Configuration requires key-value pairs. Provided an odd number of arguments to Config!"

		# Apply the definition of all options
		} else {
			foreach {Key Value} $args {
				if {[dict exist $Config $Key]} {
					dict set Config $Key $Value
				} else {
					error "'$Key' is not known configuration attribute. Valid keys are: [dict keys $Config]"
				}
			}
			return
		}
	}


	##########################
	# Proc: t2ws::DefineMimeType
	#    Define a Mime type. This command defines a Mime type for a given file 
	#    type. For convenience reasons a full qualified file name can be provided;
	#    the file type/extension is in this case extracted. If the Mime type is 
	#    already defined for a file type it will be replaced by the new one.
	#
	#    The Mime types for the following file extensions are pre-defined :
	#    .txt .htm .html .css .gif .jpg .png .xbm .js .json .xml
	#
	# Parameters:
	#    <File> - File extension or full qualified file name
	#    <MimeType> - Mime type
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::DefineMimeType .html text/html
	#    > t2ws::DefineMimeType c:/readme.txt text/plain
	#    
	# See also:
	#    <t2ws::GetMimeType>
	##########################

	proc t2ws::DefineMimeType {File MimeType} {
		variable MimeTypes
		dict set MimeTypes [string tolower [file extension $File]] $MimeType
		return
	}

	
	##########################
	# Proc: t2ws::GetMimeType
	#    Returns Mime type. This command returns the Mime type defined for a 
	#    given file. If no file is provided it returns the Mime type definition 
	#    dictionary.
	#
	# Parameters:
	#    [File] - File extension or full qualified file name
	#
	# Returns:
	#    Mime type, or Mime type definition dictionary
	#    
	# Examples:
	#    > t2ws::GetMimeType index.htm
	#    > -> text/html
	#    > t2ws::GetMimeType
	#    > -> {} text/plain .txt text/plain .htm text/html .html text/html ...
	#    
	# See also:
	#    <t2ws::DefineMimeType>
	##########################

	proc t2ws::GetMimeType { {File ""} } {
		variable MimeTypes
		if {$File!=""} {
			return [dict get $MimeTypes [string tolower [file extension $File]]]
		} else {
			return $MimeTypes
		}
	}
	

	##########################
	# Proc: t2ws::DefineStatusCode
	#    Defines a HTTP status code. This command defines a HTTP status code 
	#    together with its assigned message text.
	#
	#    The following HTTP status codes are pre-defined :
	#    * 100 101 103 
	#    * 200 201 202 203 204 205 206
	#    * 300 301 302 303 304 306 307 308
	#    * 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417 
	#    * 500 501 502 503 504 505 511
	#
	# Parameters:
	#    <Code> - HTTP status code
	#    <Message> - HTTP status message
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::DefineStatusCode 200 "OK"
	#    > t2ws::DefineStatusCode 404 "Not Found"
	#    
	# See also:
	#    <t2ws::GetStatusCode>
	##########################

	proc t2ws::DefineStatusCode {Code Message} {
		variable StatusCodes
		
		# Check the validity of the Code (3 digits)
		if {![string match {[0-9][0-9][0-9]} $Code]} {
			error "HTTP code needs to have 3 digits" }

		# Delete an eventual existing message look-up
		catch {
			set OldMessage [string range [dict get $StatusCodes $Code] [string length $Code]+1 end]
			dict unset StatusCodes [string tolower $OldMessage]
		}
		
		# Define a look-up for the code and for the message
		dict set StatusCodes $Code "$Code $Message"
		dict set StatusCodes [string tolower $Message] "$Code $Message"

		return
	}
	 
	##########################
	# Proc: t2ws::GetStatusCode
	#    Provides HTTP status code and message. This command provides for a 
	#    given HTTP code or message the concatenated code and message. If no 
	#    argument is provided it returns a dictionary of all defined HTTP codes.
	#
	# Parameters:
	#    [CodeOrMessage] - HTTP code or message
	#
	# Returns:
	#    Status code, or status code dictionary
	#    
	# Examples:
	#    > t2ws::GetStatusCode 404
	#    > -> 404 Not Found
	#    > t2ws::GetStatusCode "Not Found"
	#    > -> 404 Not Found
	#    > t2ws::GetStatusCode "Not Found"
	#    > -> 100 {100 Continue} 101 {101 Switching Protocols} 103 {103 Checkpoint} ...
	#    
	# See also:
	#    <t2ws::DefineStatusCode>
	##########################

	proc t2ws::GetStatusCode { {CodeOrMessage ""} } {
		variable StatusCodes
		if {$CodeOrMessage!=""} {
			return [dict get $StatusCodes [string tolower $CodeOrMessage]]
		} else {
			return [dict filter $StatusCodes key {[0-9][0-9][0-9]}]
		}
	}


	##########################
	# Proc: t2ws::WriteLog
	#    This command is called each time a text has to be logged. The level of
	#    details that is logged can be configured via <t2ws::Configure>. The 
	#    default implementation of this command just writes the text to stdout :
	#
	#    > proc t2ws::WriteLog {Message Tag} {
	#    >    puts $Message
	#    > }
	#
	#    The implementation of this command can be changed to adapt it to the
	#    need of a specific application.
	#
	# Parameters:
	#    <Message> - Message/text to log
	#    <Tag> - Message tag, used tags: 'info', 'input', 'output'
	#
	# Returns:
	#    -
	#    
	# See also:
	#    <t2ws::Configure>
	##########################

	proc t2ws::WriteLog {Message Tag} {
		puts $Message
	}


# Package internal commands and initialization routines

	# Package variable initializations
	
	namespace eval t2ws {
		# Global package configuration
		variable Config [dict create]
			dict set Config -protocol ""; # Forced HTTP protocol (HTTP/1.0, HTTP/1.1)
			dict set Config -default_Content-Type "text/plain"; # Default conent type
			dict set Config -log_level 1; # 0: No log, 3: maximum log

		# Server handler dict
		variable Server [dict create]
		
		# Responder procedure dict
		variable Responder [dict create]

		# Predefined status codes
		variable StatusCodes [dict create]
		foreach {SCode SMessage} {
			100 "Continue"         101 "Switching Protocols" 103 "Checkpoint"

			200 "OK"               201 "Created"             202 "Accepted"
			203 "Non-Authoritative Information"              204 "No Content"
			205 "Reset Content"    206 "Partial Content"

			300 "Multiple Choices" 301 "Moved Permanently"   302 "Found"
			303 "See Other"        304 "Not Modified"        306 "Switch Proxy"
			307 "Temporary Redirect"                         308 "Resume Incomplete"

			400 "Bad Request"      401 "Unauthorized"        402 "Payment Required"
			403 "Forbidden"        404 "Not Found"           405 "Method Not Allowed"
			406 "Not Acceptable"   407 "Proxy Authentication Required"
			408 "Request Timeout"  409 "Conflict"            410 "Gone"
			411 "Length Required"  412 "Precondition Failed" 413 "Request Entity Too Large"
			414 "Request-URI Too Long"                       415 "Unsupported Media Type"
			416 "Requested Range Not Satisfiable"            417 "Expectation Failed"

			500 "Internal Server Error"                      501 "Not Implemented"
			502 "Bad Gateway"      503 "Service Unavailable" 504 "Gateway Timeout"
			505 "HTTP Version Not Supported"                 511 "Network Authentication Required"
		} {
			DefineStatusCode $SCode $SMessage }
		unset SCode SMessage

		# Mime types
		variable MimeTypes [dict create]
		foreach {FTail MType} {
			{} text/plain .txt text/plain
			.htm text/html .html text/html
			.css text/css
			.gif image/gif .jpg image/jpeg .png image/png
			.xbm image/x-xbitmap
			.js application/javascript
			.json application/json
			.xml application/xml
		} {
			DefineMimeType $FTail $MType }
		unset FTail MType
	}


	# Logging and debugging support

	##########################
	# t2ws::Log
	#    Logs the provided message if its log level is lower or equal to the the 
	#    configured log level threshold. The message is substituted in the 
	#    scope of the calling procedure.
	#
	# Parameters:
	#    <Message> - Message/text to log
	#    [Tag] - Message tag, used tags: 'info', 'input', 'output'
	#    [Level] - Message level, default: 3
	#    [NoSubst] - If set to 1 no message substitution will be performed if set to 1
	#
	# Returns:
	#    -
	##########################

	proc t2ws::Log {Message {Tag info} {Level 3} {NoSubst 0}} {
		variable Config
		if {$Level<=[dict get $Config -log_level]} {
			if {!$NoSubst} {
				set Message [uplevel 1 "subst \{$Message\}"]}
			WriteLog $Message $Tag
		}
	}


	##########################
	# t2ws::Puts
	#    Wrapper function for 'puts'. All send transactions are performed 
	#    through this wrapper function, which allows logging the data that is
	#    transferred. The transferred data will be logged if the configured
	#    log threshold is 3.
	#
	# Parameters:
	#    [args] - Puts arguments
	#
	# Returns:
	#    -
	##########################

	proc t2ws::Puts {args} {
		variable Config
		if {3<=[dict get $Config -log_level]} {
			set Data [lindex $args end]
			if {[string length $Data]>200} {
				WriteLog "[string range $Data 0 200]\n... total [string length $Data] characters" output
			} else {
				WriteLog $Data output
			}
		}
		puts {*}$args
	}

	
	##########################
	# Accept
	#    This is the connection handler that is called if a new connection is
	#    requested. It configures the channel and defines the communication 
	#    service routine.
	##########################
	
	proc t2ws::Accept {Socket ClientAddress ClientPort} {
		Log {HttpServer::Accept $Socket $ClientAddress $ClientPort} info 2
		fconfigure $Socket -blocking 0
		fileevent $Socket readable [list [namespace current]::SocketService $Socket]
	}
	
	
	##########################
	# SocketService
	#    Communication service routine. This command is called on each HTTP 
	#    request. It parses the HTTP request data, calls the responder command,
	#    formats the response data and sent this data back to the client. The
	#    socket will be closed after completing the transaction.
	##########################

	proc t2ws::SocketService {Socket} {
		variable Status
		variable Config
		
		# Find the port of the socket
		set Port [lindex [fconfigure $Socket -sockname] 2]
		Log {HttpServer::SocketService $Socket (port $Port)} info 2

		# Check if the socket has data available, close the socket if not
		if {[eof $Socket]} {
			Log {  eof->close socket} info 2
			close $Socket
			return
		}

		# Default request data, they are overwritten if explicitly specified in 
		# the HTTP request
		set RequestMethod ""
		set RequestURI ""
		set RequestProtocol ""
		set RequestHeader [dict create connection "close" accept "text/plain" accept-encoding ""]
		set RequestBody ""
		set RequestAcceptGZip 0; # Indicates that the request accepts a gzipped response
		
		# Default response data, they are overwritten by the responder command data
		set ResponseStatus "OK"
		set ResponseBody ""
		set ResponseHeader [dict create {*}{
			Connection "close"
		}]
		set FilePath ""; # Will be set to the file path if the content of a file 
		                 # has to be returned. Has precedence over 'ResponseBody'.

		# HTTP request parser setup
		set State Connecting; # HTTP request section
		set ErrorRecord {}; # Error code, list of HTTP error code and HTML error text
		
		# Start reading the available data, line after line
		while {[gets $Socket Line]>=0} {
			Log {$Line} input 3
			# Decode the HTTP request line
			if {$State=="Connecting"} {
				if {![regexp {^(\w+) /(.*) (HTTP/[\d\.]+)} $Line {} RequestMethod RequestURI RequestProtocol]} {
					break }
				set State Header

			# Read the header/RequestData lines
			} elseif {$State=="Header"} {
				if {$Line!=""} {
					if {[regexp {^\s*([^: ]+)\s*:\s*(.*)\s*$} $Line {} AttrName AttrValue]} {
						dict set RequestHeader [string tolower $AttrName] $AttrValue
					} else {
						# RequestData not recognized, ignore it
						Log {Unable to interpret RequestData: $Line} info 2
					}
				} else {
					set State Body
				}
			}
		}

		# Return a 'bad request response in case no valid line was received
		if {$State=="Connecting"} {
			set ResponseStatus "Bad request" }

		# Read the Body (if the header section was read successfully)
		if {$State=="Body"} {
			set RequestBody [read $Socket]
			if {$RequestBody!=""} {
				Log {$RequestBody} input 3 }
		}
		
		# Determine if the response can be gzipped
		if {[regexp {\mgzip\M} [dict get $RequestHeader accept-encoding]]} {
			set RequestAcceptGZip 1 }

		# Evaluate the request if no error happened until this point.

		if {$ResponseStatus=="OK"} {
			variable Responder
			# Create the response dictionary
			set RequestMethod [string toupper $RequestMethod]
			set RequestURI [DecodeHttp $RequestURI]
			set Request [dict create Method $RequestMethod URI $RequestURI \
			                         Header $RequestHeader Body $RequestBody]

			# Call the relevant responder command
			foreach ResponderDef [dict get $Responder $Port] {
				if {[string match [lindex $ResponderDef 0] $RequestMethod] && 
				    [string match [lindex $ResponderDef 1] $RequestURI]} {
					Log {Call Responder command: [lindex $ResponderDef 2]} info 2
					catch {set Response [[lindex $ResponderDef 2] $Request]}
					break
				}
			}

			# Process the response (there was a failure if 'Response' doesn't exist)
			if {[info exists Response]} {
				if {[dict exists $Response Status]} {
					set ResponseStatus [dict get $Response Status] }
				if {[dict exists $Response Body]} {
					set ResponseBody [dict get $Response Body] }
				if {[dict exists $Response Header]} {
					set ResponseHeader [dict merge $ResponseHeader [dict get $Response Header]] }
				if {[dict exists $Response Content-Type]} {
					dict set ResponseHeader Content-Type [dict get $Response Content-Type] }
				if {[dict exists $Response NoCache] && [dict get $Response NoCache]} {
					dict set ResponseHeader Cache-Control "no-cache, no-store, must-revalidate" }
				if {[dict exists $Response File]} {
					set FilePath [dict get $Response File] }
			} else {
				set ResponseStatus 500; # There was a failure
			}
		}

		# If a file has to be provided, read the file content
		if {$ResponseStatus=="OK" && $FilePath!=""} {
			# Evaluate the MIME type. If the type is not recognized the default
			# type is used (plain text)
			if {![dict exists $ResponseHeader Content-Type]} {
				catch {
					dict set ResponseHeader Content-Type [GetMimeType $FilePath] }
			}

			# Try to provide a gzipped file if gzip encoding is accepted and if 
			# the gzipped file already exists
			
			if {[file exists $FilePath.gz] && $RequestAcceptGZip} {
				set FilePath $FilePath.gz
				dict set ResponseHeader Content-Encoding "gzip"
				set RequestAcceptGZip 0; # Don't gzip the zipped file another time
			}

			Log {    File: $FilePath} 2

			# Read the file content as binary data. Catch errors due to non 
			# existing files
			if {[catch {set f [open $FilePath RDONLY]} err]} {
				set ResponseStatus "Not Found"
				set ResponseBody "File '$FilePath' not found"
			} else {
				fconfigure $f -translation binary
				set ResponseBody [read $f]
				close $f
			}
		}

		# Evaluate the response protocol (HTTP/1.0 or HTTP/1.1)
		set ResponseProtocol $RequestProtocol
		if {[dict get $Config -protocol]!=""} {
			set ResponseProtocol [dict get $Config -protocol] }

		# Build the full response status. If the response isn't OK and if no 
		# response body is defined, create a response body containing the error info.
		catch {set ResponseStatus [GetStatusCode $ResponseStatus]}
		if {$ResponseStatus!="200 OK"} {
			if {$ResponseBody==""} {
				set ResponseBody $ResponseStatus }
		}

		# Compress the data if this is accepted by the client, 
		# supported by Tcl, and if the response is sufficient long (>100)
		if {$RequestAcceptGZip && $::tcl_version>=8.6 && [string length $ResponseBody]>100} {
			if {$FilePath!=""} {
				set ResponseBody [zlib gzip $ResponseBody \
									-header [dict create filename [file tail $FilePath]]]
			} else {
				set ResponseBody [zlib gzip $ResponseBody]
			}
			dict set ResponseHeader Content-Encoding "gzip"
		}

		# If the content type hasn't bee specified, use the default one
		if {![dict exists $ResponseHeader Content-Type] && \
		     [dict get $Config -default_Content-Type]!=""} {
			dict set ResponseHeader Content-Type [dict get $Config -default_Content-Type] }

		# Return the full response:
		
		# Return the response header lines using crlf line breaks. Evaluate and 
		# return also the content length.
		fconfigure $Socket -translation {auto crlf}; # HTTP headers need to have crlf line breaks
		Puts $Socket "$ResponseProtocol $ResponseStatus"
		dict for {DKey DVal} $ResponseHeader {
			if {$DVal!=""} {
				Puts $Socket "$DKey: $DVal" }
		}
		Puts $Socket "Content-Length: [string length $ResponseBody]"
		Puts $Socket ""; # This empty line indicates the end of the header section

		# Return the response body. Handle this data as binary, the content of 
		# some files is binary (and to match also the length RequestData).
		fconfigure $Socket -translation {auto binary}; # Binary data to match the content length RequestData
		Puts -nonewline $Socket $ResponseBody
		flush $Socket

		# Close the socket ('connection: close')
		catch {close $Socket}
		Log {t2ws: $Socket closed} info 2
	}
	
	
	##########################
	# DecodeHttp
	#    Decode the hexadecimal encoding contained in HTTP requests (e.g. %2F).
	#
	# Parameters:
	#    <Text> - HTTP encoded text
	#
	# Returns:
	#    HTTP decoded text
	#
	# Examples:
	#    
	#    > DecodeHttp {http://localhost:8080/name="t2ws client"}
	#    > -> http://localhost:8080/name=%22t2ws%20client%22
	##########################

	proc t2ws::DecodeHttp {Text} {
		# Identify hex encoded sequences (%XY), and replace these sequences by 
		# corresponding ASCII characters.
		while {[regexp -indices {%[[:xdigit:]][[:xdigit:]]} $Text Pos]} {
			set Char [format %c [scan [string range $Text [lindex $Pos 0]+1 [lindex $Pos 1]] %x]]
			set Text [string replace $Text {*}$Pos $Char]
		}
		return $Text
	}
	
	
	##########################
	# DefaultResponderCommand
	#    Default responder command that returns simply always a HTTP status 
	#    404 (Not Found).
	##########################
	
	proc t2ws::DefaultResponderCommand {Request} {
		return [dict create Status "404"]
	}

# Specify the t2ws version that is provided by this file:
package provide t2ws 0.1


##################################################
# Modifications:
# $Log: $
##################################################