if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded t2ws 0.6 [list source [file join $dir t2ws.tcl]]
package ifneeded t2ws::template 0.4 [list source [file join $dir t2ws_template.tcl]]
package ifneeded t2ws::bauth 0.2 [list source [file join $dir t2ws_bauth.tcl]]
