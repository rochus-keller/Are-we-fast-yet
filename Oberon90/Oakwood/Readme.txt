The modules with Linux_i386. prefix are suitable to be used with the stand-alone OP2 compiler
(transpiled to C99) together with multibootlinker and some binutils tricks to generate
Linux i386 executables. So far it works with a subset of the benchmarks (minimal1).
Towers crashes, NBody renders a wrong result, and the larger benchmarks don't compile with
OP2 yet.
