perl "NaturalDocs" ^
	--project "." ^
	--source "." ^
	--source "..\..\bin" ^
	--source "..\..\modules" ^
	--source "..\..\targets" ^
	--exclude-source "..\..\modules\thc_Web\www_jmobile" ^
	--output HTML "..\..\doc" ^
	-s "Default thc_doc_style"
