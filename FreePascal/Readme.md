This is a version of the "Are We Fast Yet?" benchmark suite
migrated to FreePascal 3.2.2.

The original source code was downloaded on 2020-08-08 from 
https://github.com/smarr/are-we-fast-yet/
commit 770c6649ed8e by 2020-04-03

The implementation was directly derived from the C++ and Oberon implementations.

Since Run.pas depends on the unix module for fpgettimeofday(), the implementation doesn't work on Windows (yet); I didn't test it on macOS.

It can easily be built using the command "fpc Main.pas".

This is work in progress; not all benchmarks are implemented yet. 
