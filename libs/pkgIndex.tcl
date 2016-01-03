# Source the pkgIndex files of all sub directories

foreach dir [glob -type d [file dirname [info script]]/*] {
	if {[info exists [file join $dir pkgIndex.tcl]]} {
		source [file join $dir pkgIndex.tcl] }
}
