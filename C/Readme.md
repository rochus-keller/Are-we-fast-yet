This is a version of the "Are We Fast Yet?" benchmark suite
migrated to C99.

The original source code was downloaded on 2020-08-08 from 
https://github.com/smarr/are-we-fast-yet/
commit 770c6649ed8e by 2020-04-03

The implementation was directly derived from the C++ implementation from https://github.com/rochus-keller/Are-we-fast-yet/tree/main/Cpp.

So far, all benchmarks beside DeltaBlue and Havlak have been migrated; the remaining benchmarks are work in progress.

Benchmark results can be found in https://github.com/rochus-keller/Oberon/tree/master/testcases/Are-we-fast-yet, see Are-we-fast-yet_results.ods and Are-we-fast-yet_results_linux.pdf.

As expected, the C99 implementation runs about as fast as the C++ one (the latter is about 10% faster). Richards and Json run significantly faster than C++ (factor 2 to 3) which is surprising and subject to further analysis. Compared to the C99 version generated from Oberon+, the native C99 version is about 10% faster, i.e. virtually the same performance.
