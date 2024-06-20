This is the original Lua implementation as downloaded from

https://github.com/smarr/are-we-fast-yet/
commit 770c6649ed8e by 2020-04-03
accessed 2020-08-08

There is only one modification in cd.lua line 906 to force inner_iterations to be 2 at least
and two other modifications in harness.lua to suppress intermediate result output

The implementation depends on the bit module included with LuaJIT.
It can be run with the PUC Lua 5.1 VM using the bit.c implementation
provided at http://bitop.luajit.org/download.html.
Its easiest to directly put the bit.c file in the src directory
of Lua 5.1 and build with cc *.c. To do that, remove the luac.c
file from this directory and add a call to luaopen_bit(L) to lua.c.
Then just run "cc *.c -O2 -lm -o lua".
