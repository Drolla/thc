# T<sup>2</sup>WS - Introduction

**T<sup>2</sup>WS**, the **Tiny Tcl Web Server**, is a small HTTP server that is easily deployable and embeddable in a Tcl application.

T<sup>2</sup>WS has the following features :

||Description
|--:|---
|Easy to use|A few lines are sufficient to build a file server to to provide an application API (see example below)
|Fast|About 90 responses per second on a Raspberry PI version 1
|Expandable|A plugin interface allows expanding the T<sup>2</sup>WS feature set

To add a T<sup>2</sup>WS web server to a Tcl application, load the T<sup>2</sup>WS package, create an application specific web server responder command and start the HTTP server for the desired port (e.g. 8085) :

```
 package require t2ws

 proc MyResponder {Request} {
    regexp {^/(\w*)\s*(.*)$} [dict get $Request URI] {} Command Arguments
    switch -exact -- $Command {
       "eval" {
          if {[catch {set Data [uplevel #0 $Arguments]}]} {
             return [dict create Status "405" Body "405 - Incorrect Tcl command: $Arguments"] }
          return [dict create Body $Data Content-Type "text/plain"]
       }
       "file" {
          return [dict create File $Arguments]
       }
    }
    return [dict create Status "404" Body "404 - Unknown command: $Command"]
 }

 t2ws::Start 8085 ::MyResponder
```

With this responder command example the web server will accept the commands _eval_and _file_ and return an error for other requests :

```
 http://localhost:8085/eval glob *.tcl
 -> pkgIndex.tcl t2ws.tcl
 http://localhost:8085/file pkgIndex.tcl
 -> if {![package vsatisfies [package provide Tcl] 8.5]} {return} ...
 http://localhost:8085/exec cmd.exe
 -> 404 - Unknown command: exec
```

### What's next

Start exploring the documentation resources for T<sup>2</sup>WS :

* [T<sup>2</sup>WS - Main module](https://github.com/Drolla/t2ws/wiki/t2ws) provides all information about the T<sup>2</sup>WS web server main module.
* [T<sup>2</sup>WS - Template](https://github.com/Drolla/t2ws/wiki/t2ws_template) provides information about the T<sup>2</sup>WS web server template engine plugin.
* [T<sup>2</sup>WS - Index](https://github.com/Drolla/t2ws/wiki/Index) index register.

