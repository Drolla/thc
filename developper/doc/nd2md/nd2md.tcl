#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" ${1+"$@"}
##########################################################################
# nd2md.tcl - Natural Docs to MarkDown converter
# 
# This program reads files that contain documentation in the Natural Docs
# syntax, and generates the corresponding documents in the GitHub
# MarkDown syntax.
#
# Copyright (C) 2015/2016 Andreas Drollinger
##########################################################################
# See the file "LICENSE" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: nd2md - NaturalDocs to MarkDown translator



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
proc nd2md {NdFile MdFile LinkFile Format} {
	global LanguageDefs nd2md_Link nd2md_config CreateReferenceIndexes

	# Check the language definitions
	foreach Pattern {LineCommentPattern MultiLineCommentStartPattern MultiLineCommentEndPattern} {
		if {![info exists LanguageDefs($Format,$Pattern)]} {
			puts stdout "File format '$Format' is not defined!"
			exit 1
		}
	}

	# Read the Natural Docs file
	set f [open $NdFile]
	set Data [read $f]
	close $f
	
	# Start parsing the file
	set Mode ""
	set SubMode ""
	set Section "^"; # Page begin
	set MdFileContent ""
	set LinkList {}
	set ActiveCommentSection 0
	foreach Line [split $Data "\n"] {
		set MdLine ""
		set AppendMdLine 0
		set NewSection ""
		
		set DocText ""
		set IsDocText 0
		if {!$ActiveCommentSection} {
			if {[regexp $LanguageDefs($Format,LineCommentPattern) $Line {} DocText]} {
				set IsDocText 1
			} elseif {$LanguageDefs($Format,MultiLineCommentStartPattern)!="" && [regexp $LanguageDefs($Format,MultiLineCommentStartPattern) $Line {} DocText]} {
				set IsDocText 1
				set ActiveCommentSection 1
			}
		} else { # $ActiveCommentSection
			set IsDocText 1
			if {[regexp $LanguageDefs($Format,MultiLineCommentEndPattern) $Line {} DocText]} {
				set ActiveCommentSection 0
			} else {
				set DocText $Line
			}
		}

		if {!$IsDocText} {
			set Mode ""
			set SubMode ""
		} else {
			set DocText [string trim $DocText]
			regsub -all {<} $DocText {\\<} DocText
			if {$DocText=="" || [string trim $DocText "\#"]==""} {
				set NewSection ""
			} elseif {[regexp {Title\s*:\s*(.+)} $DocText {} Title]} {
				set MdLine "\# $Title"
				set Mode Title
				set NewSection Title
				set nd2md_Link($Title) [list title $LinkFile $Title]
			} elseif {[regexp {Group\s*:\s*(.+)} $DocText {} Group] |
			          [regexp {Topics{0,1}\s*:\s*(.+)} $DocText {} Group]} {
				if {[regexp {Group\s*:\s*(.+)} $DocText]} {
					set MdLine "\#\# $Group"
				} else {
					set MdLine "\#\#\# $Group"
				}
				set Mode Group
				set NewSection Group
				if {$CreateReferenceIndexes} {
					set nd2md_Link($Group) [list group $LinkFile $Group]
				}
			} elseif {[regexp {((Proc)|(Function))\s*:\s*(.+)} $DocText {} ProcOrFunc {} {} Proc]} {
				set MdLine "***\n\#\#\# $ProcOrFunc: $Proc"
				set Mode Proc
				set NewSection Proc
				if {$CreateReferenceIndexes} {
					set nd2md_Link($Proc) [list proc $LinkFile "proc-$Proc"]
				}
			} elseif {$Mode=="Proc" && $Section=="" && [regexp {(.*[^\s]):\s*$} $DocText {} SubMode]} {
				set MdLine "\#\#\#\# $SubMode"
				set NewSection ProcSectionTitle
			} elseif {$Mode!=""} {
				regsub -all {\|} $DocText {\\|} DocTextT
	
				# Handle links
				set LinkList2 {}
				foreach {LinkInsertPos LinkPos} [lreverse [regexp -inline -indices -all {[^\w](\\<[^\s][^!?*<>|\"]*[^\s]>)[^\w]} " $DocText "]] {
					set Link [string range $DocText [lindex $LinkPos 0]+2 [lindex $LinkPos 1]-3]
					lappend LinkList2 $Link
					set DocText [string replace $DocText [expr {[lindex $LinkPos 0]+0}] [expr {[lindex $LinkPos 1]-2}] "\[$Link\]"]
				}

				# Handle images
				foreach {PictFilePos PictInsertPos} [lreverse [regexp -inline -indices -all {\(see\s+([^\s\)]+)\)} $DocText]] {
					set PictureFile [string range $DocText {*}$PictFilePos]
					if {[regexp {\.(gif)|(png)|(jpg)$} $PictureFile]} {
						set DocText [string replace $DocText {*}$PictInsertPos "!\[\]($PictureFile)"]
					}
				}
				
				if {[regexp {^[>:|](.*)$} $DocText {} Code]} {
					set NewSection Code
					set MdLine $Code
				} elseif {[regexp {^([-+*][\s].*)$} $DocText {} List]} {
					set NewSection List
					set MdLine $List
					lappend LinkList {*}$LinkList2
				} elseif {$Section=="List"} { # Paragraph extension of a list
					set MdLine $DocTextT
					set AppendMdLine 1; # Append the new line to the previous one
					set NewSection List
					lappend LinkList {*}$LinkList2
				} elseif {[regexp {^(.+?)\s+-\s+(.+)$} $DocTextT {} Col0 Col1]} { # Definition list: Will be transformed in a table
					if {$nd2md_config(deflist_mapping)=="table"} {
						if {$Section!="DefList"} {
							set MdLine "|$SubMode|Description\n|--:|---\n" }
						append MdLine "|$Col0|$Col1"
					} else {
						set MdLine "- **$Col0** : $Col1"
					}
					set NewSection DefList
				} elseif {$Section=="DefList"} { # Paragraph extension of a definition list
					set MdLine $DocTextT
					set AppendMdLine 1; # Append the new line to the previous one
					set NewSection DefList
				} elseif {$Section=="" && [regexp {^([^\s].*[^\s]):\s*$} $DocText {} Heading]} { # Heading, only valid if the previous line is empty
					set MdLine "\#\#\#\# $Heading"
					set NewSection Heading
				} else {
					regsub -all {^-$} $DocText {\-} DocText
					set MdLine $DocText
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
	
	# Apply custom regular expression replacements
	foreach RegSubDef $::nd2md_regsub {
		regsub -all [lindex $RegSubDef 0] $MdFileContent [lindex $RegSubDef 1] MdFileContent
	}
	
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
				lappend Links(proc) [list [list $ProcName $ProcNS] $LinkText]
			}
			"title" {
				lappend Links(doc) [list [list $LinkText ""] $LinkText]
			}
		}
	}

	# Open the Index MarkDown file, and write the content
	set f [open $MdIndexFile w]
	puts $f "\# $::nd2md_config(index_file_title)"
	
	
	foreach {SectionKey SectionTitle AddSubSections} {
		doc "Documents" 0
		proc "Procedures" 1
	} {
		puts $f "\n\## $SectionTitle\n"
		set SubSection ""
		foreach Link [lsort -index 0 -dictionary $Links($SectionKey)] {
			set NsText [lindex $Link 0 1]
			if {$NsText!=""} {
				set NsText ", $NsText" }
			set NewSubSection [string toupper [string index [lindex $Link 0 0] 0]]
			if {$AddSubSections && $NewSubSection!=$SubSection} {
				puts $f "\n\#### $NewSubSection\n"
				set SubSection $NewSubSection }
			puts $f "  * \[[lindex $Link 0 0]\]([GetLink [lindex $Link end]])$NsText"
		}
	}

	close $f
}

# Load the settings and index cache
proc LoadConfigAndIndex {} {
	uplevel {
		# Load the language definitions. Load first the global and then the local
		# definitions
		source [file join [file dirname [info script]] "_nd2md.language_defs"]
		catch {source "_nd2md.language_defs"}

		# Load the tool settings. Load first the global and then the local
		# definitions
		source [file join [file dirname [info script]] "_nd2md.settings"]
		catch {source "_nd2md.settings"}

		# Load the local doc index
		catch {source "_nd2md.index"}
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

# Parse the arguments
# nd2md.tcl 
#    [-d <Destination Directory>]
#    [-o <OutputMdFile>]
#    [-f <InputFormat>]
#    [-x]                          - Generate new index MD file
#    [-n]                          - Don't create reference indexes for the file content
#    NdFile1 [NdFile2, ...]
set GenIndex 0
set DestDir $nd2md_DestDir
set OutFile ""
set Format ""
set NdFileList {}
set CreateReferenceIndexes 1
for {set a 0} {$a<[llength $argv]} {incr a} {
	switch -exact [lindex $argv $a] {
		-d {set DestDir [lindex $argv [incr a]]}
		-o {set OutFile [lindex $argv [incr a]]}
		-f {set Format [lindex $argv [incr a]]}
		-x {set GenIndex 1}
		-n {set CreateReferenceIndexes 0}
		default {lappend NdFileList [lindex $argv $a]}
	}
}

if {$OutFile!="" && [llength $NdFileList]!=1} {
	puts stderr "Exact one NdFile has to be provided if the option -o is defined"
	exit 1
}

# Create the destination directory if not yet existing
file mkdir $DestDir

# Extract from all provided files the NaturalDocs documentation and generate 
# the corresponding MarkDown file.
foreach NdFile $NdFileList {
	if {$OutFile!=""} {
		set MdFile $OutFile
	} else {
		regsub {\.\w*$} [file tail $NdFile] {.md} MdFile
		if {[regexp {/modules/} $NdFile]} {set MdFile "Module-$MdFile"}
		if {[regexp {/targets/} $NdFile]} {set MdFile "Target-$MdFile"}
		catch {set MdFile $nd2md_nd2md($NdFile)}
		set MdFile $DestDir/$MdFile
	}
	
	set LinkFile [file tail $MdFile]
	regsub {\.md$} $LinkFile {} LinkFile
	
	set FileFormat $Format
	if {$FileFormat==""} {
		regexp {\.(\w*)$} [file tail $NdFile] {} FileFormat
	}
	set FileFormat [string tolower $FileFormat]
		
	#if {[file exists $MdFile] && [file mtime $NdFile]<[file mtime $MdFile]} continue
		
	nd2md $NdFile $MdFile $LinkFile $FileFormat
}

if {[llength $NdFileList]} StoreIndex

if {$GenIndex} {
	GenIndexFile $DestDir/$nd2md_config(index_file) }

exit