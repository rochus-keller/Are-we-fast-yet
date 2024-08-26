This is a version of the "Are We Fast Yet?" benchmark suite
migrated to C99.

The original source code was downloaded on 2020-08-08 from 
https://github.com/smarr/are-we-fast-yet/
commit 770c6649ed8e by 2020-04-03

The implementation was directly derived from the C++ implementation from https://github.com/rochus-keller/Are-we-fast-yet/tree/main/Cpp.

Different approaches have been used for the benchmarks using OO: DeltaBlue uses tagged unions, whereas Json uses virtual tables.

All benchmarks have been checked with Valgrind for memory leaks and unexpected performance patterns.

Benchmark results can be found in https://github.com/rochus-keller/Oberon/tree/master/testcases/Are-we-fast-yet, see Are-we-fast-yet_results.ods (Linux i386 tab).

As expected, the C99 implementation runs about as fast as the C++ one (the latter is about 2% faster in geomean). Richards and Json run significantly faster (factor 2 to 3), Havlak and DeltaBlue significantly slower (factor 3 and 2) than C++, which is surprising and subject to further analysis. Compared to the C99 version generated from Oberon+, the native C99 version is only about 20% faster.

The benchmark suite can be easily built using "gcc *.c som/*.c -O2 -std=c99 -lm", or the included qmake file.
