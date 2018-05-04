### Get `lib` file from `dll`

1. use visual studio command prompt

        dumpbin /exports win32\sqlite3.dll > sqlite3.x86.def
        dumpbin /exports win64\sqlite3.dll > sqlite3.x64.def

1. edit `sqlite3.ARCH.def` and take only names of functions and add `EXPORTS` to first line

        EXPORTS
        sqlite3_aggregate_context
        sqlite3_aggregate_count
        sqlite3_auto_extension
        sqlite3_backup_finish
        ...
        ~240 lines

1. in vs command prompt 

        lib /def:sqlite3.x86.def /OUT:win32\sqlite3.lib /MACHINE:x86
        lib /def:sqlite3.x64.def /OUT:win64\sqlite3.lib /MACHINE:x64
