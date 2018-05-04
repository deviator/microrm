### Get `lib` file from `dll`

1. use visual studio command prompt

        cd win32
        dumpbin /exports sqlite3.dll > sqlite3.def
        cd ..\win64
        dumpbin /exports sqlite3.dll > sqlite3.def

1. edit `sqlite3.ARCH.def` and take only names of functions and add `EXPORTS` to first line

        EXPORTS
        sqlite3_aggregate_context
        sqlite3_aggregate_count
        sqlite3_auto_extension
        sqlite3_backup_finish
        ...
        ~240 lines

1. in vs command prompt 

        cd win32
        lib /def:sqlite3.def /OUT:sqlite3.lib /MACHINE:x86
        cd ..\win64
        lib /def:sqlite3.def /OUT:sqlite3.lib /MACHINE:x64
