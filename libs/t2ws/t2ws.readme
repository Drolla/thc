# T<sup>2</sup>WS - Tiny Tcl Web Server

T<sup>2</sup>WS is a small HTTP server that is easily deployable and embeddable in a
Tcl application. To add a T<sup>2</sup>WS web server to a Tcl application, load the T<sup>2</sup>WS
package and start the HTTP server for the desired port (e.g. 8085) :

```
 package require t2ws
 t2ws::Start 8085 ::MyResponder
```

The T<sup>2</sup>WS web server requires an application specific responder command that
provides the adequate responses to the HTTP requests. The HTTP request data
are provided to the responder command in form of a dictionary, and the T<sup>2</sup>WS
web server expects to get back from the responder command the response also
in form of a dictionary. The following lines implements a responder command
example that allows either executing Tcl commands or that lets the T<sup>2</sup>WS
server returning file contents.

```
 proc MyResponder {Request} {
    regexp {^/(\w*)\s*(.*)$} [dict get $Request URI] {} Command Arguments
    switch -exact -- $Command {
       "eval" {
          if {[catch {set Data [uplevel #0 $Arguments]}]} {
             return [dict create Status "405" Body "405 - Incorrect Tcl command: $Arguments"] }
          return [dict create Body $Data ContentType "text/plain"]
       }
       "file" {
          return [dict create File $Arguments]
       }
    }
    return [dict create Status "404" Body "404 - Unknown command: $Command"]
 }
```

The web server will accept the commands _eval_ and _file_ and return an error

||Description
|--:|---
|(404|unknown command) for other requests :

```
 http://localhost:8085/eval glob *.tcl
 -> pkgIndex.tcl t2ws.tcl
 http://localhost:8085/file pkgIndex.tcl
 -> if {![package vsatisfies [package provide Tcl] 8.5]} {return} ...
 http://localhost:8085/exec cmd.exe
 -> 404 - Unknown command: exec
```

More information about starting and stopping T<sup>2</sup>WS servers and assigning
responder commands are provided in section [Main API commands]. Details about
the way the responder commands are working are provided in section
[The responder command].

## Main API commands

The following group of commands is usually sufficient to deploy a web
server.

***
### Proc: t2ws::Start

Starts a T<sup>2</sup>WS server. This command starts a T<sup>2</sup>WS HTTP web server at
the specified port. It returns the specified port.

Optionally, a responder command can be specified that is either applied
for all HTTP request methods (GET, POST, ...) and all request URIs, or
for a specific request method and URI. Additional responder commands
for other request methods and/or URIs can be specified later with
[t2ws::DefineRoute].

##### Parameters

|Parameters|Description
|--:|---
|\<Port>|HTTP port
|[Responder]|Responder command, optional
|[Method]|HTTP request method glob matching pattern, default="*"
|[URI]|HTTP request URI glob matching pattern, default="*"

##### Returns

HTTP port (used as T<sup>2</sup>WS server identifier)

##### Examples

```
 set MyServ [t2ws::Start $Port ::Responder_GetGeneral GET]
```

##### See also

[t2ws::DefineRoute], [t2ws::Stop]

***
### Proc: t2ws::Stop

Stops one or multiple T<sup>2</sup>WS servers. If no port is provided all running
T<sup>2</sup>WS servers are stopped, otherwise only the one specified by the
provided port.

##### Parameters

|Parameters|Description
|--:|---
|[Ports]|HTTP ports of the T<sup>2</sup>WS server that have to be stopped

##### Returns

\-

##### Examples

```
 t2ws::Stop $MyServ
```

##### See also

[t2ws::Start]

***
### Proc: t2ws::DefineRoute

Defines a responder command. The arguments 'Method' and 'URI' allow
applying the specified responder command for a specific HTTP request
method (GET, POST, ...) and for specific request URIs.

##### Parameters

|Parameters|Description
|--:|---
|\<Port>|HTTP port
|\<Responder>|Responder command
|[Method]|HTTP request method glob matching pattern, default="*"
|[URI]|HTTP request URI glob matching pattern, default="*"

##### Returns

\-

##### Examples

```
 t2ws::DefineRoute $MyServ ::Responder_GetApi GET api/*
```

##### See also

[t2ws::Start]

## The responder command

The T<sup>2</sup>WS web server calls each HTTP request a responder command that has
to be provided by the application. This responder command receives the
entire HTTP request data in form of a dictionary, and it has to provide
back to the server the HTTP response data again in form of another
dictionary.

##### Responder command setup

[t2ws::Start] in combination with [t2ws::DefineRoute] allow specifying
different responder commands for different HTTP request methods and URIs.
The T<sup>2</sup>WS web server selects the target responder command by trying to
match the HTTP request method and URI with the method and URI patterns
that have been defined together with the responder commands. Complexer
method and URI patterns are tried to be matched first and simpler patterns
later. The responder command definition order is therefore irrelevant.
The following line contain some responder command definition examples :

```
 set MyServ [t2ws::Start $Port ::Responder_General * *]
 t2ws::DefineRoute $MyServ ::Responder_GetApi GET /api/*
 t2ws::DefineRoute $MyServ ::Responder_GetApiPriv GET /api/privat/*
 t2ws::DefineRoute $MyServ ::Responder_GetFile GET /file/*
```

##### Request data dictionary

The responder command receives all HTTP request data in form of a
dictionary that contains the following elements :

||Description
|--:|---
|Method|Request method in upper case (e.g. GET, POST, ...)
|URI|Request URI, including leading '/'
|URITail|Request URI starting at the first place holder location
|Header|Request header data, formed itself as dictionary using as keys the header field names in lower case
|Body|Request body, binary data

##### Response data dictionary

The responder command returns the response data to the server in form of
a dictionary. All elements of this dictionary are optional. The main
elements are :

||Description
|--:|---
|Status|Either a known HTTP status code (e.g. '404'), a known HTTP status message (e.g. 'Not Found') or a custom status string (e.g. '404 File Not Found'). The default status value is '200 OK'. See \<t2ws::DefineStatusCode> and \<t2ws::GetStatusCode> for the HTTP status code and message definitions.
|Body  |HTTP response body, binary encoded. The default body data is an empty string.
|Header|Custom HTTP response headers fields, case sensitive (!). The header element is itself a dictionary that can specify multiple header fields.

The following auxiliary elements of the response dictionary are
recognized by the T<sup>2</sup>WS server :

||Description
|--:|---
|Content-Type|For convenience reasons the content type can directly be specified with this element instead of the corresponding header field.
|File        |If this element is defined the content of the file is read by the T<sup>2</sup>WS web server and sent as HTTP response body to the client.
|NoCache     |If the value of this element is true (e.g. 1) the HTTP client is informed that the data is volatile (by sending the header field: Cache-Control: no-cache, no-store, must-revalidate).

##### Examples of responder commands

The following responder command returns simply the HTTP status 404. It can
be defined to respond to invalid requests.

```
 proc Responder_General {Request} {
    return [dict create Status "404"]
 }
```

The next responder command extracts from the request URI a Tcl command.
This one will be executed and the result returned in the respond body.

```
 proc Responder_GetApi {Request} {
    set TclScript [dict get $Request URITail]
    if {[catch {set Result [uplevel #0 $TclScript]}]} {
       return [dict create Status "405" Body "405 - Incorrect Tcl command: $TclScript"] }
    return [dict create Body $Result]
 }
```

The next responder command extracts from the request URI a File name, that
will be returned to the T<sup>2</sup>WS web server. The file server will return to
the client the file content.

```
 proc Responder_GetFile {Request} {
    set File [dict get $Request URITail]
    return [dict create File $File]
 }
```

Rather than creating multiple responder commands for different targets it
is also possible to create a single one that handles all the different
requests.

```
 proc Responder_General {Request} {
    regexp {^/([^\s]*)\s*(.*)$} [dict get $Request URI] {} Target ReqLine
    switch -exact -- $Target {
       "" -
       "help" {
          set Data "\<h1>THC HTTP Debug Server\</h1>\n\
                    help: this help information\<br>\n\
                    eval [TclCommand]: Evaluate a Tcl command and returns the result\<br>\n\
                    file/show [File]: Get file content\<br>\n\
                    download [File]: Get file content (force download in a browser)"
          return [dict create Body $Data ContentType .html]
       }
       "eval" {
          if {[catch {set Data [uplevel #0 $ReqLine]}]} {
             return [dict create Status "405" Body "405 - Incorrect Tcl command: $ReqLine"] }
          return [dict create Body $Data]
       }
       "file" - "show" {
          return [dict create File $ReqLine ContentType "text/plain"]
       }
       "download" {
          return [dict create File $ReqLine ContentType "" Header [dict create Content-Disposition "attachment; filename=\"[file tail $ReqLine]\""]]
       }
       "default" {
          return [dict create Status "404" Body "404 - Unknown command: $ReqLine"]
       }
    }
 }
```

## Configuration and customization

The following group of commands allows configuring and customizing T<sup>2</sup>WS to
application specific needs.

***
### Proc: t2ws::Configure

Set and get T<sup>2</sup>WS configuration options. This command can be called in
3 different ways :

||Description
|--:|---
|t2ws::Configure|Returns the currently defined T<sup>2</sup>WS configuration
|t2ws::Configure \<Option>|Returns the value of the provided option
|t2ws::Configure \<Option/Value pairs>|Define options with new values

The following options are supported :

||Description
|--:|---
|-protocol|Forced response protocol. Has to be 'HTTP/1.0' or 'HTTP/1.1'
|-default_Content-Type|Default content type if it is not explicitly specified by the responder command or if it cannot be derived from the file extension
|-log_level|Log level, 0: no log, 1 (default): T<sup>2</sup>WS server start/stop logged, 2: transaction starts are logged, 3: full HTTP transfer is logged.

##### Parameters

|Parameters|Description
|--:|---
|[Option1]|Configuration option 1
|[Value1] |Configuration value 1
|...      |Additional option/value pairs can follow

##### Returns

Configuration options (if the command is called in way 1 or 2)

##### Examples

```
 t2ws::Configure
 -> -protocol {} -default_Content-Type text/plain -log_level 1
 t2ws::Configure -default_Content-Type
 -> text/plain
 t2ws::Configure -default_Content-Type text/html
```

***
### Proc: t2ws::DefineMimeType

Define a Mime type. This command defines a Mime type for a given file
type. For convenience reasons a full qualified file name can be provided;
the file type/extension is in this case extracted. If the Mime type is
already defined for a file type it will be replaced by the new one.

The Mime types for the following file extensions are pre-defined :
.txt .htm .html .css .gif .jpg .png .xbm .js .json .xml

##### Parameters

|Parameters|Description
|--:|---
|\<File>|File extension or full qualified file name
|\<MimeType>|Mime type

##### Returns

\-

##### Examples

```
 t2ws::DefineMimeType .html text/html
 t2ws::DefineMimeType c:/readme.txt text/plain
```

##### See also

[t2ws::GetMimeType]

***
### Proc: t2ws::GetMimeType

Returns Mime type. This command returns the Mime type defined for a
given file. If no file is provided it returns the Mime type definition
dictionary.

##### Parameters

|Parameters|Description
|--:|---
|[File]|File extension or full qualified file name

##### Returns

Mime type, or Mime type definition dictionary

##### Examples

```
 t2ws::GetMimeType index.htm
 -> text/html
 t2ws::GetMimeType
 -> {} text/plain .txt text/plain .htm text/html .html text/html ...
```

##### See also

[t2ws::DefineMimeType]

***
### Proc: t2ws::DefineStatusCode

Defines a HTTP status code. This command defines a HTTP status code
together with its assigned message text.

The following HTTP status codes are pre-defined :

* 100 101 103
* 200 201 202 203 204 205 206
* 300 301 302 303 304 306 307 308
* 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417
* 500 501 502 503 504 505 511

##### Parameters

|Parameters|Description
|--:|---
|\<Code>|HTTP status code
|\<Message>|HTTP status message

##### Returns

\-

##### Examples

```
 t2ws::DefineStatusCode 200 "OK"
 t2ws::DefineStatusCode 404 "Not Found"
```

##### See also

[t2ws::GetStatusCode]

***
### Proc: t2ws::GetStatusCode

Provides HTTP status code and message. This command provides for a
given HTTP code or message the concatenated code and message. If no
argument is provided it returns a dictionary of all defined HTTP codes.

##### Parameters

|Parameters|Description
|--:|---
|[CodeOrMessage]|HTTP code or message

##### Returns

Status code, or status code dictionary

##### Examples

```
 t2ws::GetStatusCode 404
 -> 404 Not Found
 t2ws::GetStatusCode "Not Found"
 -> 404 Not Found
 t2ws::GetStatusCode "Not Found"
 -> 100 {100 Continue} 101 {101 Switching Protocols} 103 {103 Checkpoint} ...
```

##### See also

[t2ws::DefineStatusCode]

***
### Proc: t2ws::WriteLog

This command is called each time a text has to be logged. The level of
details that is logged can be configured via [t2ws::Configure]. The
default implementation of this command just writes the text to stdout :

```
 proc t2ws::WriteLog {Message Tag} {
    puts $Message
 }
```

The implementation of this command can be changed to adapt it to the
need of a specific application.

##### Parameters

|Parameters|Description
|--:|---
|\<Message>|Message/text to log
|\<Tag>|Message tag, used tags: 'info', 'input', 'output'

##### Returns

\-

##### See also

[t2ws::Configure]

[Main API commands]: #main-api-commands
[The responder command]: #the-responder-command
[t2ws::Configure]: #proc-t2wsconfigure
[t2ws::DefineMimeType]: #proc-t2wsdefinemimetype
[t2ws::DefineRoute]: #proc-t2wsdefineroute
[t2ws::DefineStatusCode]: #proc-t2wsdefinestatuscode
[t2ws::GetMimeType]: #proc-t2wsgetmimetype
[t2ws::GetStatusCode]: #proc-t2wsgetstatuscode
[t2ws::Start]: #proc-t2wsstart
[t2ws::Stop]: #proc-t2wsstop
