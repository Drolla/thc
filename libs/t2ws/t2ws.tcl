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
# Group: Introduction
#
# T2WS is a HTTP server that is easily deployable and embeddable in a Tcl 
# application. To add a T2WS web server to a Tcl application, load the T2WS 
# package and start the HTTP server for the desired port (e.g. 8085) :
#
#    > package require t2ws
#    > t2ws::Start 8085 -responder ::MyResponder
#
# The <t2ws::Start> command accepts as '-responder' argument an application 
# specific responder command that provides for each HTTP request the adequate 
# response. The HTTP request data are provided to the responder command in form 
# of a dictionary, and the T2WS web server expects to get back from the 
# responder command the response also in form of a dictionary.  The following 
# lines implements a responder command example that allows either executing Tcl 
# commands or that lets the T2WS server returning file contents.
#
#    > proc MyResponder {Request} {
#    >    regexp {^/(\w*)\s*(.*)$} [dict get $Request URI] {} Command Arguments
#    >    switch -exact -- $Command {
#    >       "eval" {
#    >          if {[catch {set Data [uplevel #0 $Arguments]}]} {
#    >             return [dict create Status "405" Body "405 - Incorrect Tcl command: $Arguments"] }
#    >          return [dict create Body $Data Content-Type "text/plain"]
#    >       }
#    >       "file" {
#    >          return [dict create File $Arguments]
#    >       }
#    >    }
#    >    return [dict create Status "404" Body "404 - Unknown command: $Command"]
#    > }
#
# With this responder command the web server will accept the commands _eval_ 
# and _file_ and return an error for other requests :
#
#    > http://localhost:8085/eval glob *.tcl
#    > -> pkgIndex.tcl t2ws.tcl
#    > http://localhost:8085/file pkgIndex.tcl
#    > -> if {![package vsatisfies [package provide Tcl] 8.5]} {return} ...
#    > http://localhost:8085/exec cmd.exe
#    > -> 404 - Unknown command: exec
#
# More information about starting and stopping T2WS servers and assigning 
# responder commands are provided in section <Main API commands>. Details about
# the way the responder commands are working are provided in section 
# <The responder command>.


# Package namespace declaration

	package require Tcl 8.5

	namespace eval t2ws {}

	##########################
	# Assert
	#    Assert a condition. This procedure assert that a condition is 
	#    satisfied. If the provided condition is not true an error is raised.
	##########################

	proc t2ws::Assert {Condition Message} {
		if {[uplevel 1 "expr \{$Condition\}"]} return
		error $Message
	}


# Group: Main API commands
# The following group of commands is usually sufficient to deploy a web server.
	
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
	#    By default, a non-secure network socket is opened to support conventional 
	#    HTTP connections. If certification and key files are provided 
	#    respectively via the '-certfile' and '-keyfile' arguments and if the TLS 
	#    package has been previously loaded, a secure network connections is 
	#    opened to support secured HTTPS connections. If the TLS package hasn't 
	#    been previously loaded an error is generated. See also <Secure connections>.
	#
	# Parameters:
	#    <Port> - HTTP port
	#    [-responder <Responder>] - Responder command, optional
	#    [-method <Method>] - HTTP request method glob matching pattern. Ignored 
	#              if option '-responder' isn't defined. Set to "*" if not defined
	#    [-uri <URI>] - HTTP request URI glob matching pattern. Ignored if 
	#              option '-responder' isn't defined. Set to "*" if not defined
	#
	# Additional parameters for secured connections only (TLS/HTTPS):
	#    -certfile <CertFile> - SSL certification file
	#    -keyfile <KeyFile> - SSL keyfile. Required if option '-certfile' is 
	#              defined, ignored if it is not defined.
	#    [<args>] - Additional arguments that are passed to 'tls::socket'.
	#
	# Returns:
	#    HTTP/HTTPS port (used as T2WS server identifier)
	#    
	# Examples:
	#    > # Non-secure connection
	#    > set MyServ [t2ws::Start $Port -responder ::Responder_GetGeneral -method GET]
	#    
	#    > # Secure connection: A password handler is declared with the 
	#    > # additional argument '-password'
	#    > package require tls
	#    > set MyServS [t2ws::Start $PortS -responder ::Responder_GetGeneral -method GET \
	#    >    -certfile cert.pem -keyfile key.pem -password ::PwService]
	#    > proc PwService {args} {return "MyPassword123"}
	#    
	# See also:
	#    <t2ws::DefineRoute>, <t2ws::Stop>
	##########################
	
	proc t2ws::Start {Port args} {
		variable Server
		
		# Argument handling and checks
		set Options [dict create -responder "" -method "*" -uri "*" -certfile "" -keyfile "" {*}$args]
		Assert {[dict get $Options -certfile]=="" || [dict get $Options -keyfile]!=""} "Keyfile isn't defined"

		# Stop an already running server. Start the server
		Stop $Port
		Log {HttpServer::Start $Port} info 1
		
		# Open a secure connection if the '-certfile' argument is defined. Check 
		# in this case that the 'tls' package has been loaded. Provide all 
		# arguments to the 'tls::socket' command except the ones related to
		# 't2ws::Start'
		if {[dict get $Options -certfile]!=""} {
			if {[catch {package present tls}]} {
				return -code error "Load package 'tls' to open a secure connection!" }
			dict set Server $Port [::tls::socket -server [namespace current]::Accept \
			                          {*}[dict remove $Options -responder -method -uri] $Port]
		
		# Open a non-secure socket if no certification file is provided
		} else {
			dict set Server $Port [socket -server [namespace current]::Accept $Port]
		}

		# Define the default responder command, and if defined the custom command
		DefineRoute $Port t2ws::DefaultResponderCommand -method "*" -uri "*"
		if {[dict get $Options -responder]!=""} {
			DefineRoute $Port [dict get $Options -responder] -method [dict get $Options -method] -uri [dict get $Options -uri] }

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
	#    [-method <Method>] - HTTP request method glob matching pattern. Ignored 
	#              if option -responder isn't defined. Set to "*" if not defined
	#    [-uri <URI>] - HTTP request URI glob matching pattern. Ignored if 
	#              option -responder isn't defined. Set to "*" if not defined
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::DefineRoute $MyServ ::Responder_GetApi -method GET -uri /api/*
	# 
	# See also:
	#    <t2ws::Start>
	##########################

	proc t2ws::DefineRoute {Port ResponderCommand args} {
		variable Server
		variable Responder
		
		# Argument handling and checks
		if {![dict exists $Server $Port]} {
			error "No server for port $Port defined" }
		set Options [dict create -method "*" -uri "*" {*}$args]

		# Evaluate the position of the variable URI begin (the location of the 
		# first place holder * or ?. Ignore place holders preceded by a backslash.
		if {[regexp {^[*?]} [dict get $Options -uri]]} { # * or ? on the line begin
			set URITailPos 0
		} elseif {[regexp {[^\\][*?]} [dict get $Options -uri]]} { # First * or ? location without preceding bs
			set URITailPos [lindex [regexp -inline -indices {[^\\][*?]} [dict get $Options -uri]] 0 1]
		} else {
			set URITailPos [string length [dict get $Options -uri]]; # No place holder -> the URI has no variable part
		}

		# Add the new responder command to the list of the related port, and sort 
		# it afterwards.
		dict lappend Responder $Port [list [string toupper [dict get $Options -method]] [dict get $Options -uri] $URITailPos $ResponderCommand]
		dict set Responder $Port [lsort -unique -command ResponderCompare -decreasing [dict get $Responder $Port]]
	}
	
	##########################
	# t2ws::ResponderCompare
	#    Compares 2 responder command definitions and returns 0 if they are 
	#    equally weighted or -1 or 1 if they have a precedence. The URL 
	#    definition is compared first, and if it is equal the method is compared.
	#    This function is used by the responder command definition sort of 
	#    t2ws::DefineRoute.
	##########################
	
	proc t2ws::ResponderCompare {r0 r1} {
		set Url0 [string range [lindex $r0 1] 0 [lindex $r0 2]-1]
		set Url1 [string range [lindex $r1 1] 0 [lindex $r1 2]-1]
		set UrlDiff [string compare $Url0 $Url1]
		if {$UrlDiff} {
			return $UrlDiff }
		set MethodDiff [string compare [lindex $r0 0] [lindex $r1 0]]
		return $MethodDiff
	}


# Group: The responder command
# The T2WS web server calls each HTTP request a responder command that has to 
# be provided by the user application. This responder command receives all HTTP 
# request data in form of a dictionary, and it has to provide back to the 
# server the HTTP response data again in form of another dictionary. 
# Alternatively, the responder command can also build the response via a set of 
# dedicated commands (see <Response manipulation>).
#
# Topic: Responder command setup
#
# <t2ws::Start> and <t2ws::DefineRoute> allow specifying different responder 
# commands for different HTTP request methods and URIs. The T2WS web server 
# selects the target responder command by trying to match the HTTP request 
# method and URI with the method and URI patterns that have been defined 
# together with the responder commands. More complex method and URI patterns 
# are tried to be matched first and simpler patterns later. The responder 
# command definition order is therefore irrelevant.
# The following line contain some responder command definition examples :
#
#    > set MyServ [t2ws::Start $Port ::Responder_General -method * -uri *]
#    > t2ws::DefineRoute $MyServ ::Responder_GetApi -method GET -uri /api/*
#    > t2ws::DefineRoute $MyServ ::Responder_GetApiPriv -method GET -uri /api/privat/*
#    > t2ws::DefineRoute $MyServ ::Responder_GetFile -method GET -uri /file/*
#
# Topic: Request data dictionary
#
# The responder command receives all HTTP request data in form of a dictionary 
# that contains the following elements :
#
#    Method  - Request method in upper case (e.g. GET, POST, ...)
#    URI     - Request URI, including leading '/'
#    URITail - Request URI starting after the first place holder location
#    Header  - Request header data, formed itself as dictionary using as keys 
#              the header field names in lower case
#    Body    - Request body, binary data
#
# Topic: Response data dictionary
#
# The responder command has to return the response data to the server in form 
# of a dictionary. All elements of this dictionary are optional. The main 
# elements are :
#
#     Status - Either a known HTTP status code (e.g. '404'), a known HTTP 
#              status message (e.g. 'Not Found') or a custom status string 
#              (e.g. '404 File Not Found'). The default status value is 
#              '200 OK'. See <t2ws::DefineStatusCode> and 
#              <t2ws::GetStatusCode> for the HTTP status code and message 
#              definitions.
#     Body   - HTTP response body, binary encoded. The default body data is 
#              an empty string.
#     Header - Custom HTTP response headers fields, case sensitive (!). The 
#              header element is itself a dictionary that can specify multiple
#              header fields.
#
# The following auxiliary elements of the response dictionary are recognized 
# and processed by the T2WS server :
#  
#     Content-Type - For convenience reasons the content type can directly be 
#                    specified with this element instead of the corresponding 
#                    header field.
#     File         - If this element is defined the content of the file is read 
#                    by the T2WS web server and sent as HTTP response body to 
#                    the client.
#     NoCache      - If the value of this element is true (e.g. 1) the HTTP 
#                    client is informed that the data is volatile (by sending 
#                    the header field: Cache-Control: no-cache, no-store, 
#                    must-revalidate).
#
# Specific fields are used by the HTTP server to register errors. This error 
# information is especially used by plugins (see <Plugin/Extension API>), but 
# also responder commands can make use of them. 
#  
#     ErrorStatus  - If defined an error has been encountered and this field 
#                    provides the error status. The 'normal' fields Status and 
#                    Body are ignored by the T2WS server.
#     ErrorBody    - Provides optionally the HTTP body for the case ErrorStatus 
#                    is defined.
#
# Examples of responder commands:
#
# The following responder command simply returns the HTTP status 404. It can be 
# defined to respond to invalid requests.
#
#    > proc Responder_General {Request} {
#    >    return [dict create Status "404"]
#    > }
#
# The next responder command extracts from the request URI a Tcl command. This 
# one will be executed and the result returned in the respond body.
#
#    > proc Responder_GetApi {Request} {
#    >    set TclScript [dict get $Request URITail]
#    >    if {[catch {set Result [uplevel #0 $TclScript]}]} {
#    >       return [dict create Status "405" Body "405 - Incorrect Tcl command: $TclScript"] }
#    >    return [dict create Body $Result]
#    > }
#
# The next responder command extracts from the request URI a File name, that 
# will be returned to the T2WS web server. The file server will return to the 
# client the file content.
#
#    > proc Responder_GetFile {Request} {
#    >    set File [dict get $Request URITail]
#    >    return [dict create File $File]
#    > }
#
# Rather than creating multiple responder commands for different targets it is 
# also possible to create a single one that handles all the different requests.
#
#    > proc Responder_General {Request} {
#    >    regexp {^/(\w*)(?:[/ ](.*))?$} [dict get $Request URI] {} Target ReqLine
#    >    switch -exact -- $Target {
#    >       "" -
#    >       "help" {
#    >          set Data "<h1>THC HTTP Debug Server</h1>\n\
#    >                    help: this help information<br>\n\
#    >                    eval <TclCommand>: Evaluate a Tcl command and returns the result<br>\n\
#    >                    file/show <File>: Get file content<br>\n\
#    >                    download <File>: Get file content (force download in a browser)"
#    >          return [dict create Body $Data Content-Type .html]
#    >       }
#    >       "eval" {
#    >          if {[catch {set Data [uplevel #0 $ReqLine]}]} {
#    >             return [dict create Status "405" Body "405 - Incorrect Tcl command: $ReqLine"] }
#    >          return [dict create Body $Data]
#    >       }
#    >       "file" - "show" {
#    >          return [dict create File $ReqLine Content-Type "text/plain"]
#    >       }
#    >       "download" {
#    >          return [dict create File $ReqLine Content-Type "" Header [dict create Content-Disposition "attachment; filename=\"[file tail $ReqLine]\""]]
#    >       }
#    >       "default" {
#    >          return [dict create Status "404" Body "404 - Unknown command: $ReqLine. Call 'help' for support."]
#    >       }
#    >    }
#    > }

	##########################
	# DefaultResponderCommand
	#    Default responder command that returns simply always a HTTP status 
	#    404 (Not Found).
	##########################

	proc t2ws::DefaultResponderCommand {Request} {
		return [dict create Status "404"]
	}


# Group: Response manipulation
# The T2WS server initializes for each HTTP request a response dictionary prior 
# to the call of the responder command. The responder commands can use a set of 
# commands to manipulate this response dictionary; <t2ws::AddResponse> adds new 
# fields or replaces already defined ones, <t2ws::UnsetResponse> removes fields, 
# and <t2ws::SetResponse> re-defines the full response dictionary. Response that 
# is directly returned by the responder command are added to the current 
# response dictionary in the same  way <t2ws::AddResponse> adds response fields 
# to the dictionary.
#
# The examples illustrate three different ways to build the same response :
#
#    > # Direct response return
#    > proc t2ws::Responder1 {Request} {
#    >    return [dict create Status 404 Body $::NotFoundHtmlGz8p Content-Type .html \
#    >                        Header [dict create Content-Encoding gzip Server "T2WS"]]
#    > }
#
#    > # Combination of explicit response definition and direct response return
#    > proc t2ws::Responder1 {Request} {
#    >    t2ws::AddResponse [dict create Content-Type .html Header [dict create Server "T2WS"]]
#    >    return [dict create Status 404 Body $::NotFoundHtmlGz8p Header [dict create Content-Encoding gzip]]
#    > }
#
#    > # Combination of multiple explicit response definitions
#    > proc t2ws::Responder1 {Request} {
#    >    t2ws::AddResponse [dict create Status 404]
#    >    t2ws::AddResponse [dict create Body $::NotFoundHtmlGz8p]
#    >    t2ws::AddResponse [dict create Content-Type .html]
#    >    t2ws::AddResponse [dict create Header [dict create Content-Encoding gzip]]
#    >    t2ws::AddResponse [dict create Header [dict create Server "T2WS"]]
#    >    return
#    > }
#
# The the available response commands are described below :

	# Response dictionary variable
	variable Response

	
	##########################
	# Proc: t2ws::SetResponse
	#    Initializes and defines the response dictionary. The existing response
	#    is discarded.
	#
	# Parameters:
	#    [Response] - New response data dictionary. If not provided the response 
	#                 directory is just initialized.
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::SetResponse [dict create Status "405" Body "405 - Incorrect Tcl command: $TclScript"]
	# 
	# See also:
	#    <t2ws::AddResponse>, <t2ws::UnsetResponse>
	##########################

	proc t2ws::SetResponse { {Response {}} } {
		ClearResponse
		AddResponse $Response
	}

	##########################
	# t2ws::ClearResponse
	#    Initializes the response dictionary. Internally used.
	##########################
	
	proc t2ws::ClearResponse {} {
		variable Response [dict create Header [dict create Connection "close"] Body "" Status OK]
		return
	}


	##########################
	# Proc: t2ws::AddResponse
	#    Adds response fields to the response dictionary. Already defined 
	#    dictionary fields are replaced by the new fields.
	#
	# Parameters:
	#    <Response> - Dictionary with additional response data
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::AddResponse [dict create Header [dict create Set-Cookie "$Cookie; expires=[clock format $Expires];"]]
	# 
	# See also:
	#    <t2ws::SetResponse>, <t2ws::UnsetResponse>
	##########################

	proc t2ws::AddResponse {ResponseN} {
		variable Response
		if {[dict exists $ResponseN Header]} {
			dict set Response Header [dict merge [dict get $Response Header] [dict get $ResponseN Header]]
			dict unset ResponseN Header }
		set Response [dict merge $Response $ResponseN]
		return
	}

	
	##########################
	# Proc: t2ws::UnsetResponse
	#    Remove response information from the response dictionary.
	#
	# Parameters:
	#    <KeyList> - List of keys to remove from the existing response
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::UnsetResponse {Status {Header Set-Cookie}}
	# 
	# See also:
	#    <t2ws::SetResponse>, <t2ws::AddResponse>
	##########################

	proc t2ws::UnsetResponse {KeyList} {
		variable Response
		foreach Key $KeyList {
			if {[lindex $Key 0]=="Header"} {
				foreach HKey [lrange $Key 1 end] {
					dict unset Response Header $HKey }
			} else {
				dict unset Response $Key
			}
		}
		return
	}


# Group: Configuration and customization
# The following group of commands allows configuring and customizing T2WS to 
# application specific needs.

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
	#    T2WS predefines the Mime types for the following file extensions :
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
	#    given file. If no Mime type matches with a file the default Mime type 
	#    is returned (see <t2ws::Configure>). If no file is provided it returns 
	#    the full Mime type definition dictionary.
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
		variable Config
		if {$File!=""} {
			set FileExtension [string tolower [file extension $File]]
			if {[dict exists $MimeTypes $FileExtension]} {
				return [dict get $MimeTypes $FileExtension]
			} else {
				return [dict get $Config -default_Content-Type]
			}
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
	#    given HTTP code or message the concatenated code and message. If the 
	#    provided HTTP code or message is not defined an error is raised. If no 
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
	#    > t2ws::GetStatusCode
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
			dict set Config -default_Content-Type "text/plain"; # Default content type
			dict set Config -log_level 1; # 0: No log, 3: maximum log
			dict set Config -session_duration {1 minute}; # Session duration

		# Server handler dict
		variable Server [dict create]
		
		# Responder procedure dict
		variable Responder [dict create]
		
		# Plugin list
		variable Plugins {}

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

		# Predefined Mime types
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
	#    configured log level threshold. The message is substituted in the scope 
	#    of the calling procedure.
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
	#    transferred. The transferred data will be logged if the configured log 
	#    threshold is 3.
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
	#    request. It parses the HTTP request data, calls the responder command 
	#    and eventually defined plugins, formats the response data and sent this 
	#    data back to the client. The socket will be closed after completing the 
	#    transaction.
	##########################

	proc t2ws::SocketService {Socket} {
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
		
		# Initial response dictionary data. The different fields are overwritten 
		# by the responder command data
		variable Response
		ClearResponse; # Header={Connection="close"}; Body=""; Status=OK

		# HTTP request parser setup
		set State Connecting; # HTTP request section
		
		# Start reading the available data, line after line
		while {[gets $Socket Line]>=0} {
			Log {$Line} input 3
			# Decode the HTTP request line
			if {$State=="Connecting"} {
				if {![regexp {^(\w+)\s+(/.*)\s+(HTTP/[\d\.]+)} $Line {} RequestMethod RequestURI RequestProtocol]} {
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

		# If the state is still 'connecting' just the socket has been opened but 
		# no data has been transferred. Close in this situation the socket without
		# returning a response.
		if {$State=="Connecting"} {
			Log {  No data received -> close socket} info 2
			catch {close $Socket}
			return
		}

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
		if {![dict exists $Response ErrorStatus]} {
			variable Responder
			# Create the response dictionary
			set RequestMethod [string toupper $RequestMethod]
			set RequestURI [UrlDecode $RequestURI]

			# Call the relevant responder command
			foreach ResponderDef [dict get $Responder $Port] {
				if {[string match [lindex $ResponderDef 0] $RequestMethod] && 
				    [string match [lindex $ResponderDef 1] $RequestURI]} {
					set RequestURITail [string range $RequestURI [lindex $ResponderDef 2] end]; # Neg index are handled as 0
					set Request [dict create Method $RequestMethod URI $RequestURI \
					                         URITail $RequestURITail \
													 Header $RequestHeader Body $RequestBody]
					Log {Call Responder command: [lindex $ResponderDef 3]} info 2
					catch {set ResponseD [[lindex $ResponderDef 3] $Request]}
					break
				}
			}

			# Process the response (there was a failure if 'ResponseD' doesn't exist)
			if {[info exists ResponseD]} {
				AddResponse $ResponseD
			} else {
				dict set Response ErrorStatus 500; # There was a failure
			}
		}

		# If a file has to be provided, read the file content
		set FilePath ""; # File path if the content of a file has to be returned.
		if {![dict exists $Response ErrorStatus] && [dict exists $Response File]} {
			set FilePath [dict get $Response File] }
		if {$FilePath!=""} {
			# Evaluate the MIME type. If the type is not recognized the default
			# type is used (plain text)
			if {![dict exists $Response Header Content-Type]} {
				dict set Response Header Content-Type [GetMimeType $FilePath] }

			# Try to provide a gzipped file if gzip encoding is accepted and if 
			# the gzipped file already exists
			
			if {[file exists $FilePath.gz] && $RequestAcceptGZip} {
				set FilePath $FilePath.gz
				dict set Response Header Content-Encoding "gzip"
				set RequestAcceptGZip 0; # Don't gzip the zipped file another time
			}

			Log {    File: $FilePath} 2

			# Read the file content as binary data. Catch errors due to non 
			# existing files
			if {[catch {set f [open $FilePath RDONLY]} err]} {
				dict set Response ErrorStatus "Not Found"
				dict set Response ErrorBody "File '$FilePath' not found"
			} else {
				fconfigure $f -translation binary
				dict set Response Body [read $f]
				close $f
			}
		}

		# Execute the registered plugin commands, add the returned responses to 
		# the response dictionary
		variable Plugins
		foreach Plugin $Plugins {
			if {[catch {$Plugin $Request}]} {
				dict set Response ErrorStatus 500; # There was a failure
			}
		}

		# If an error happened, define the HTTP response status and body
		if {[dict exists $Response ErrorStatus]} {
			if {[dict exists $Response ErrorBody]} {
				SetResponse [dict create Status [dict get $Response ErrorStatus] \
				                         Body [dict get $Response ErrorBody]]
			} else {
				SetResponse [dict create Status [dict get $Response ErrorStatus] Body ""] }

		# If no error happened, set some auxiliary header fields
		} else {
			if {[dict exists $Response Content-Type]} {
				dict set Response Header Content-Type [dict get $Response Content-Type] }
			if {[dict exists $Response NoCache] && [dict get $Response NoCache]} {
				dict set Response Header Cache-Control "no-cache, no-store, must-revalidate" }
		}
		
		# Evaluate the response protocol (HTTP/1.0 or HTTP/1.1)
		set ResponseProtocol $RequestProtocol
		if {[dict get $Config -protocol]!=""} {
			set ResponseProtocol [dict get $Config -protocol] }

		# Build the full response status. If the response isn't OK and if no 
		# response body is defined, create a response body that contains the error info.
		catch {
			dict set Response Status [GetStatusCode [dict get $Response Status]] }
		if {[dict get $Response Status]!="200 OK" && [dict get $Response Body]==""} {
				dict set Response Body [dict get $Response Status] }

		# Compress the data if this is accepted by the client, supported by Tcl, 
		# and if the response is sufficient long (>100)
		if {$RequestAcceptGZip && $::tcl_version>=8.6 && [string length [dict get $Response Body]]>100} {
			if {$FilePath!=""} {
				dict set Response Body [zlib gzip [dict get $Response Body] \
									              -header [dict create filename [file tail $FilePath]]]
			} else {
				dict set Response Body [zlib gzip [dict get $Response Body]]
			}
			dict set Response Header Content-Encoding "gzip"
		}

		# If the content type hasn't bee specified, use the default one
		if {![dict exists $Response Header Content-Type] && \
		     [dict get $Config -default_Content-Type]!=""} {
			dict set Response Header Content-Type [dict get $Config -default_Content-Type] }

		# Return the full response:
		
		# Return the response header lines using crlf line breaks. Evaluate and 
		# return also the content length.
		fconfigure $Socket -translation {auto crlf}; # HTTP headers need to have crlf line breaks
		Puts $Socket "$ResponseProtocol [dict get $Response Status]"
		dict for {DKey DVal} [dict get $Response Header] {
			regsub {:.*$} $DKey {} DKey; # Remove an eventual ending :* sequence 
			if {$DVal!=""} {
				Puts $Socket "$DKey: $DVal" }
		}
		Puts $Socket "Content-Length: [string length [dict get $Response Body]]"
		Puts $Socket ""; # This empty line indicates the end of the header section

		# Return the response body. Handle this data as binary, the content of 
		# some files is binary (and to match also the length RequestData).
		fconfigure $Socket -translation {auto binary}; # Binary data to match the content length RequestData
		Puts -nonewline $Socket [dict get $Response Body]
		flush $Socket

		# Close the socket ('connection: close')
		catch {close $Socket}
		Log {t2ws: Done, close $Socket} info 2
	}


	# URL encoding/decoding: See http://wiki.tcl.tk/14144

	##########################
	# t2ws::UrlCodecInit
	#    Initializes the string mapping array used by the URL encoder and 
	#    decoder
	##########################
	
	proc t2ws::UrlCodecInit {} {
		variable UrlCodeMap
		for {set i 0} {$i <= 256} {incr i} { 
			set c [format %c $i]
			if {![string match \[a-zA-Z0-9\] $c]} {
				set UrlCodeMap($c) %[format %.2x $i]
			}
		}
		# These are handled specially
		array set UrlCodeMap {\n %0d%0a }; # Orig: " " + 
	}
	t2ws::UrlCodecInit

	
	##########################
	# t2ws::UrlEncode
	#    Encodes special characters of an URL in a HTTP requests by the 
	#    hexadecimal representation (e.g. %2F).
	#
	# Parameters:
	#    <Text> - URL/text
	#
	# Returns:
	#    URL encoded text
	#
	# Examples:
	#    
	#    > UrlEncode {http://localhost:8080/name="t2ws client"}
	#    > -> http://localhost:8080/name=%22t2ws%20client%22
	##########################

	proc t2ws::UrlEncode {Text} {
		variable UrlCodeMap
	
		# The spec says: "non-alphanumeric characters are replaced by '%HH'"
		# 1 leave alphanumerics characters alone
		# 2 Convert every other character to an array lookup
		# 3 Escape constructs that are "special" to the tcl parser
		# 4 "subst" the result, doing all the array substitutions
	
		regsub -all \[^a-zA-Z0-9\] $Text {$UrlCodeMap(&)} Text
		# This quotes cases like $UrlCodeMap([) or $UrlCodeMap($) => $UrlCodeMap(\[) ...
		regsub -all {[][{})\\]\)} $Text {\\&} Text
		return [subst -nocommand $Text]
	}

	
	##########################
	# t2ws::UrlDecode
	#    Decode the hexadecimal encoding contained in HTTP requests (e.g. %2F).
	#
	# Parameters:
	#    <Text> - URL encoded text
	#
	# Returns:
	#    URL decoded text
	#
	# Examples:
	#    
	#    > UrlDecode {http://localhost:8080/name=%22t2ws%20client%22}
	#    > -> http://localhost:8080/name="t2ws client"
	##########################

	proc t2ws::UrlDecode {Text} {
		# rewrite "+" back to space
		# protect \ from quoting another '\'
		set Text [string map [list + { } "\\" "\\\\"] $Text]
	
		# prepare to process all %-escapes
		regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $Text {\\u00\1} Text
	
		# process \u unicode mapped chars
		return [subst -novar -nocommand $Text]
	}


	##########################
	# t2ws::HtmlEncode
	#    Encodes special characters in Html code by the 
	#    hexadecimal representation (e.g. %2F).
	#
	# Parameters:
	#    <Text> - HTML code/Text
	#
	# Returns:
	#    HTTP decoded text
	#
	# Examples:
	#    
	#    > UrlEncode {http://localhost:8080/name="t2ws client"}
	#    > -> http://localhost:8080/name=%22t2ws%20client%22
	##########################

	proc t2ws::HtmlEncode {Text} {
		regsub -all {[\[\{]} $Text {(} Text
		regsub -all {[\}\]]} $Text {)} Text
		regsub -all "\"" $Text {'} Text
		# regsub -all {\\} $Text {\\\\} Text
		regsub -all {[\u0000-\u001f\u007f-\uffff]} $Text {?} Text
		return $Text
	}

	
# Group: Plugin/Extension API
#
# The T2WS server functionality can be extended via plugins. A plugin provides 
# a command that is registered with <t2ws::DefinePlugin>. Once registered this 
# plugin command is called by the T2WS server after each execution of the 
# responder command.
#
# The HTTP request dictionary is provided as argument to the plugins. Reading 
# and manipulating the HTTP response dictionary happens by accessing the 
# response variable of the enclosing procedure via 'upvar'. Optionally a plugin 
# command can also modify or complete the current response via the commands 
# <t2ws::AddResponse> and <t2ws::UnsetResponse>.
#
# It may be necessary to adapt the plugin command behavior in case the HTTP 
# server encountered an error. Such errors are indicated by a defined 
# ErrorStatus field of the response dictionary. Possible reasons for errors 
# are files that are not existing, connection problems, or an error raised by 
# an responder command.
#
# The following example registers a plugin command that adds the header  
# fields 'Server' and 'Date' to the existing response 
# (using <t2ws::AddResponse>). If no error happened also the 'ETag' attribute 
# is added in form of a MD5 checksum of the Body (by directly writing the 
# referred response dictionary variable).
# 
#    > package require md5
#    > 
#    > proc Plugin_DateServerMd5 {Request} {
#    >    upvar Response Response; # Refer the response dictionary variable
#    > 
#    >    # 
#    >    set Date [clock format [clock seconds] -format "%a, %d %b %Y %T %Z"]
#    >    t2ws::AddResponse [dict create Header [dict create Server "T2WS" Date $Date]]
#    > 
#    >    if {[dict exists $Response ErrorStatus]} return
#    >    
#    >    set ETag [md5::md5 -hex [dict get $Response Body]]
#    >    dict set Response Header ETag "\"$ETag\""
#    > }
#    > 
#    > t2ws::DefinePlugin Plugin_DateServerMd5


	##########################
	# Proc: t2ws::DefinePlugin
	#    Registers a plugin command. Multiple plugin commands can be registered.
	#
	# Parameters:
	#    <Command> - Plugin command
	#
	# Returns:
	#    -
	#    
	# Examples:
	#    > t2ws::DefinePlugin ::MyT2wsPlugin
	##########################

	proc t2ws::DefinePlugin {Command} {
		variable Plugins
		# Register the  plugin command
		lappend Plugins $Command
		return
	}

	
# Group: Secure connections
#
# If the TLS package is loaded secure network sockets can be opened by providing 
# to the <t2ws::Start> command a certification file and a key file.
#
# Key and certification files can be generated with OpenSSL. The following 
# lines contain a simple example of a key and certification file generation. 
# The second line that generates the certificate will ask to enter additional
# parameters via the command line interface :
#
# > # Private RSA key pair generation:
# > openssl genrsa -out key.pem 1024
# >
# > # Certificate generation
# > openssl req -new -x509 -key key.pem -out cert.pem -days 365
#
# An extensive documentation about key and certification generation can be 
# found online on the OpenSSL website <https://www.openssl.org/> and on many 
# other websites.
#
# Secured websites are not accessible via the traditional HTTP protocol, but
# via the HTTPS protocol, which has to be indicated in the URL provided to 
# the web browsers (e.g. https://localhost:8085).
#
# Note that most web browser will indicate a security problem if the used 
# certificate is either not signed at all, or signed by its own and not by
# an official certificate authority. The browsers will ask in these situations 
# to acknowledge a security exception.

	
# Specify the t2ws version that is provided by this file:

	package provide t2ws 0.4


##################################################
# Modifications:
# $Log: $
##################################################