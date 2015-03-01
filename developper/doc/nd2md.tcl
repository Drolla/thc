#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# THC - Tight Home Control
##########################################################################
# nd2md.tcl - Natural Docs to MarkDown converter
# 
# This program reads files that contain documentation in the Natural Docs
# syntax, and generates the corresponding document in the MarkDown syntax.
#
# Copyright (C) 2015 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

proc nd2md {NdFile MdFile} {
	# Read the Natural Docs file
	set f [open $NdFile]
	set Data [read $f]
	close $f

	# Define the comment pattern
	set CommentPattern "\\s*\#\\s*(.*)"; # Tcl comments
	if {[regexp {\.txt$} $NdFile]} {
		set CommentPattern "(.*)"; # Txt file
	}
	
	# Start parsing the file
	set Mode ""
	set SubMode ""
	set Section "^"; # Page begin
	set MdFileContent ""
	foreach Line [split $Data "\n"] {
		set MdLine ""
		set AppendMdLine 0
		set NewSection ""
		if {[regexp $CommentPattern $Line {} Comment]} {
			set Comment [string trim $Comment]
			regsub -all {<} $Comment {\\<} Comment
			if {$Comment=="" || [string trim $Comment "\#"]==""} {
				set NewSection ""
			} elseif {[regexp {Title\s*:\s*(.+)} $Comment {} Title]} {
				set MdLine "\# $Title"
				set Mode Title
				set NewSection Title
			} elseif {[regexp {Group\s*:\s*(.+)} $Comment {} Group] |
			          [regexp {Topics{0,1}\s*:\s*(.+)} $Comment {} Group]} {
				set MdLine "\#\# $Group"
				set Mode Group
				set NewSection Group
			} elseif {[regexp {Proc\s*:\s*(.+)} $Comment {} Proc]} {
				set MdLine "***\n\#\#\# Proc: $Proc"
				set Mode Proc
				set NewSection Proc
			} elseif {$Mode=="Proc" && [regexp {(.*)\s*:\s*$} $Comment {} SubMode]} {
				set MdLine "\#\#\#\#\# $SubMode"
				set NewSection ProcSectionTitle
			} elseif {$Mode!=""} {
				regsub -all {\|} $Comment {\\|} CommentT
				if {[regexp {^>(.*)$} $Comment {} Code]} {
					set NewSection Code
					set MdLine $Code
				} elseif {[regexp {^([-+*].*)$} $Comment {} List]} {
					set NewSection List
					set MdLine $List
				} elseif {[regexp {^(.+) - (.+)$} $CommentT {} Col0 Col1]} { # Definition list: Will be transformed in a table
					if {$Section!="DefList"} {
						set MdLine "|$SubMode|Description\n|--:|---\n"
					}
					set NewSection DefList
					append MdLine "|$Col0|$Col1"
				} elseif {$Section=="DefList"} { # Paragraph extension of a definition list
					set MdLine $CommentT
					set AppendMdLine 1; # Append the new line to the previous one
					set NewSection DefList
				} elseif {$Section=="" && [regexp {^([^\s].*[^\s]):\s*$} $Comment {} Heading]} { # Heading, only valid if the previous line is empty
					set MdLine "\#\#\#\#\# $Heading"
					set NewSection Heading
				} else {
					regsub -all {^-$} $Comment {\-} Comment
					set MdLine $Comment
					set NewSection "Paragraph"
				}
			}
			if {$Section=="Code" && $NewSection!="Code"} {
				append MdFileContent "\n```"; # End a code section
			}
			if {$NewSection!=$Section && $NewSection!="" && $Section!="^"} {
				append MdFileContent "\n"; # Add an empty line between the sections
			}
			
			#puts "$Mode ::$Section :: $NewSection --- $MdLine"
			if {$MdLine!=""} {
				if {!$AppendMdLine} {
					append MdFileContent "\n"
				} elseif {[string index $MdFileContent end]!=""} {
					append MdFileContent " "
				}
				if {$NewSection=="Code" && $Section!="Code"} {
					append MdFileContent "```\n"; # Start a code section
				}
				append MdFileContent $MdLine
			}
			set Section $NewSection
		} else {
			set Mode ""
			set SubMode ""
			set Section ""
		}
	}
	
	# Open the MarkDown file, and write the content
	set f [open $MdFile w]
	puts -nonewline $f $MdFileContent
	close $f
}

foreach NdFile $argv {
	regsub {\.\w*$} [file tail $NdFile] {.md} MdFile
	if {[regexp {/modules/} $NdFile]} {set MdFile "Module-$MdFile"}
	if {[regexp {/targets/} $NdFile]} {set MdFile "Target-$MdFile"}
	nd2md $NdFile md/$MdFile
}
exit