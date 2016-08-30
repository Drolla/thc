# T<sup>2</sup>WS - Introduction

**T<sup>2</sup>WS**, the **Tiny Tcl Web Server**, is a small HTTP server that is easily deployable and embeddable in Tcl applications.

T<sup>2</sup>WS has the following features :

- **Easy to use** : A few lines are sufficient to build a file server to to provide an application API (see example below)
- **Fast** : About 90 responses per second on a Raspberry PI version 1
- **Multi-port support** : Can handle simultaneously multiple sites or ports
- **Expandable** : A plugin interface allows expanding the T<sup>2</sup>WS feature set
- **Template engine** : A template engine is available via a plugin
- **SSL/TLS support** : Secure connections are supported if the TLS package is available

To add a T<sup>2</sup>WS web server to a Tcl application, load the T<sup>2</sup>WS package, create an application specific web server responder command and start the HTTP server for the desired port (e.g. 8085) :

```
 package require t2ws

 proc MyResponder {Request} {
    # Process the request URI: Extract a command and its arguments
    regexp {^/(\w*)/(.*)$} [dict get $Request URI] {} Command Arguments

    # Implement the different commands (eval <TclCommand>, file <File>)
    switch -exact -- $Command {
       "eval" {
          set Data [uplevel #0 $Arguments]
          return [dict create Body $Data Content-Type "text/plain"] }
       "file" {
          return [dict create File $Arguments] }
    }

    # Return the status 404 (not found) if the command is unknown
    return [dict create Status "404"]
 }

 t2ws::Start 8085 -responder ::MyResponder
```

With this responder command example the web server will accept the commands _eval_ and _file_ and return an error for other requests :

```
 http://localhost:8085/eval/glob *.tcl
 -> pkgIndex.tcl t2ws.tcl t2ws_template.tcl
 http://localhost:8085/file/pkgIndex.tcl
 -> if {![package vsatisfies [package provide Tcl] 8.5]} {return} ...
 http://localhost:8085/exec/cmd.exe
 -> 404 Not Found
```

Multiple responder commands can be defined for different purposes. The following example is equivalent to the previous one, but it uses separate responder commands for the command evaluation and for the file access :

```
 package require t2ws

 proc MyResponder_Eval {Request} {
    set Data [uplevel #0 [dict get $Request URITail]]
    return [dict create Body $Data Content-Type "text/plain"]
 }

 proc MyResponder_File {Request} {
    return [dict create File [dict get $Request URITail]]
 }

 set Port [t2ws::Start 8085]
 t2ws::DefineRoute $Port ::MyResponder_Eval -method GET -uri "/eval/*"
 t2ws::DefineRoute $Port ::MyResponder_File -method GET -uri "/file/*"
```

### What's next

Start exploring the documentation resources for T<sup>2</sup>WS :

* [T<sup>2</sup>WS - Main module](https://github.com/Drolla/t2ws/wiki/t2ws) provides all information about the T<sup>2</sup>WS web server main module.
* [T<sup>2</sup>WS - Template](https://github.com/Drolla/t2ws/wiki/t2ws_template) provides information about the T<sup>2</sup>WS web server template engine plugin.
* [T<sup>2</sup>WS - Index](https://github.com/Drolla/t2ws/wiki/Index) index register.

