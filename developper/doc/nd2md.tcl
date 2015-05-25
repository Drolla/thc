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

# Build and return from a link text the MD link.
proc GetLink {LinkText {LinkFile ""}} {
	global nd2md_Link
	set Link $LinkText
	if {[info exists nd2md_Link($Link)]} {
		set LkFile [lindex $nd2md_Link($Link) 1]
		if {$LkFile==$LinkFile} {
			set LkFile ""}
		set LkSection [string tolower [lindex $nd2md_Link($Link) 2]]
		regsub -all {:} $LkSection {} LkSection
		regsub -all { } $LkSection {-} LkSection
		set Link "$LkFile\#$LkSection"
	}
	return $Link
}

# Parse the NaturalDoc documentation in a file, and generate the corresponding
# MarkDown file.
proc nd2md {NdFile MdFile LinkFile} {
	global nd2md_Link
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
	set LinkList {}
	foreach Line [split $Data "\n"] {
		set MdLine ""
		set AppendMdLine 0
		set NewSection ""

		if {![regexp $CommentPattern $Line {} Comment]} {
			set Mode ""
			set SubMode ""
		} else {
			set Comment [string trim $Comment]
			regsub -all {<} $Comment {\\<} Comment
			if {$Comment=="" || [string trim $Comment "\#"]==""} {
				set NewSection ""
			} elseif {[regexp {Title\s*:\s*(.+)} $Comment {} Title]} {
				set MdLine "\# $Title"
				set Mode Title
				set NewSection Title
				set nd2md_Link($Title) [list title $LinkFile $Title]
			} elseif {[regexp {Group\s*:\s*(.+)} $Comment {} Group] |
			          [regexp {Topics{0,1}\s*:\s*(.+)} $Comment {} Group]} {
				set MdLine "\#\# $Group"
				set Mode Group
				set NewSection Group
				set nd2md_Link($Group) [list group $LinkFile $Group]
			} elseif {[regexp {Proc\s*:\s*(.+)} $Comment {} Proc]} {
				set MdLine "***\n\#\#\# Proc: $Proc"
				set Mode Proc
				set NewSection Proc
				set nd2md_Link($Proc) [list proc $LinkFile "proc-$Proc"]
			} elseif {$Mode=="Proc" && $Section=="" && [regexp {(.*[^\s]):\s*$} $Comment {} SubMode]} {
				set MdLine "\#\#\#\#\# $SubMode"
				set NewSection ProcSectionTitle
			} elseif {$Mode!=""} {
				regsub -all {\|} $Comment {\\|} CommentT
	
				# Handle links
				set LinkList2 {}
				foreach {LinkInsertPos LinkPos} [lreverse [regexp -inline -indices -all {[^\w](\\<[^\s][^!?*<>|\"]*[^\s]>)[^\w]} " $Comment "]] {
					set Link [string range $Comment [lindex $LinkPos 0]+2 [lindex $LinkPos 1]-3]
					lappend LinkList2 $Link
					set Comment [string replace $Comment [expr {[lindex $LinkPos 0]+0}] [expr {[lindex $LinkPos 1]-2}] "\[$Link\]"]
				}

				# Handle images
				foreach {PictFilePos PictInsertPos} [lreverse [regexp -inline -indices -all {\(see\s+([^\s\)]+)\)} $Comment]] {
					set PictureFile [string range $Comment {*}$PictFilePos]
					if {[regexp {\.(gif)|(png)|(jpg)$} $PictureFile]} {
						set Comment [string replace $Comment {*}$PictInsertPos "!\[\]($PictureFile)"]
					}
				}
				
				if {[regexp {^[>:|](.*)$} $Comment {} Code]} {
					set NewSection Code
					set MdLine $Code
				} elseif {[regexp {^([-+*][\s].*)$} $Comment {} List]} {
					set NewSection List
					set MdLine $List
					lappend LinkList {*}$LinkList2
				} elseif {$Section=="List"} { # Paragraph extension of a list
					set MdLine $CommentT
					set AppendMdLine 1; # Append the new line to the previous one
					set NewSection List
					lappend LinkList {*}$LinkList2
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
					lappend LinkList {*}$LinkList2
				}
			}
		}
		if {$Section=="Code" && $NewSection!="Code"} {
			append MdFileContent "\n```"; # End a code section
		}
		if {$NewSection!=$Section && $NewSection!="" && $Section!="^"} {
			append MdFileContent "\n"; # Add an empty line between the sections
		}
		
		#append MdFileContent "\n[string repeat { } 90]$Mode :: $Section :: $NewSection\n"
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
	}
	
	# Add the link references
	append MdFileContent "\n\n" 
	foreach LinkText [lsort -unique $LinkList] {
		append MdFileContent "\[$LinkText\]: [GetLink $LinkText $LinkFile]\n"
	}
	
	# Remove leading empty lines
	set MdFileContent [string trimleft $MdFileContent "\n\t "]
	
	# Open the MarkDown file, and write the content
	set f [open $MdFile w]
	puts -nonewline $f $MdFileContent
	close $f
}

# Generate the index file
proc GenIndexFile {MdIndexFile} {
	global nd2md_Link

	# Classify all links
	array set Links {proc  {} doc {}}
	foreach {LinkText v} [array get nd2md_Link] {
		switch [lindex $v 0] {
			"proc" {
				set ProcName $LinkText
				set ProcNS ""
				regexp {^(.*)::(.+?)$} $LinkText {} ProcNS ProcName
				lappend Links(proc) [list "$ProcName - ${ProcNS}::${ProcName}" $LinkText]
			}
			"title" {
				lappend Links(doc) [list $LinkText]
			}
		}
	}

	# Open the Index MarkDown file, and write the content
	set f [open $MdIndexFile w]
	puts $f "\# THC - Index"
	
	foreach {SectionKey SectionTitle} {
		doc "Documents"
		proc "Procedures"
	} {
		puts $f "\n\## $SectionTitle\n"
		foreach Link [lsort -index 0 -dictionary $Links($SectionKey)] {
			puts $f "  * \[[lindex $Link 0]\]([GetLink [lindex $Link end]])"
		}
	}

	close $f
}

# Load the settings and index cache
proc LoadConfigAndIndex {} {
	uplevel {
		array set nd2md_nd2md {}
		set nd2md_DestDir "md"
		array set nd2md_Link {}
		catch {source _nd2md.settings}
		catch {source _nd2md.index}
	}
}

# Store the index
proc StoreIndex {} {
	global nd2md_Link
	set f [open _nd2md.index w]
	
	puts $f "array set nd2md_Link \{"
	foreach {n v} [array get nd2md_Link] {
		puts $f "  \"$n\" \{$v\}"
	}
	puts $f "\}"
	
	close $f
}

# Load the settings
LoadConfigAndIndex

# Create the destination directory if not yet existing
file mkdir $nd2md_DestDir

# Extract from all provided files the NaturalDocs documentation and generate 
# the corresponding MarkDown file.
# If no file has been provided generate the index file.
if {$argv!={}} {
	foreach NdFile $argv {
		regsub {\.\w*$} [file tail $NdFile] {.md} MdFile
		if {[regexp {/modules/} $NdFile]} {set MdFile "Module-$MdFile"}
		if {[regexp {/targets/} $NdFile]} {set MdFile "Target-$MdFile"}
		catch {set MdFile $nd2md_nd2md($NdFile)}
		set MdFile $nd2md_DestDir/$MdFile
	
		set LinkFile [file tail $MdFile]
		regsub {\.md$} $LinkFile {} LinkFile
		
		#if {[file exists $MdFile] && [file mtime $NdFile]<[file mtime $MdFile]} continue
		
		nd2md $NdFile $MdFile $LinkFile
	}
	
	StoreIndex
} else {
	GenIndexFile $nd2md_DestDir/THC-Index.md
}
	
exit