if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded t2ws 0.1 [list source [file join $dir t2ws.tcl]]
