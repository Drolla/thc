::::::::::::::::::::::::::::::::::
:: Generate HTML Documentation with NaturalDocs
::::::::::::::::::::::::::::::::::
::
:: To generate the HTML documentation NaturalDocs and Perl need to be installed 
:: and the NaturalDocs launch command specified below. The location where the
:: generated HTML documentation will be stored can also be specified below.
::
::::::::::::::::::::::::::::::::::

:: Specify the NaturalDocs launch command. Examples:
::   set NaturalDocsCommand=perl "C:\Program Files\NaturalDocs\NaturalDocs"
::   set NaturalDocsCommand="C:\Program Files (86)\Perl\bin\perl.exe "C:\Program Files\NaturalDocs\NaturalDocs"
set NaturalDocsCommand=perl "..\..\..\NaturalDocs\NaturalDocs"

:: Specify the HTML documentation target directory. Examples:
::    set DestinationDir = "..\..\doc"
set DestinationDir="..\..\doc"

:::::::::::::::::::::::::::::::::::::


%NaturalDocsCommand% ^
  --project "." ^
  --source "." ^
  --source "..\..\bin" ^
  --source "..\..\modules" ^
  --source "..\..\targets" ^
  --exclude-source "..\..\modules\thc_Web\www_jmobile" ^
  --output HTML %DestinationDir% ^
  -s "Default thc_doc_style"
