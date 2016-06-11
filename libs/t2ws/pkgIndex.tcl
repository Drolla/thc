if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded t2ws 0.2 [list source [file join $dir t2ws.tcl]]
package ifneeded t2ws_template 0.1 [list source [file join $dir t2ws_template.tcl]]
