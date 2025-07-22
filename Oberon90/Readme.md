This is a version of the "Are We Fast Yet?" benchmark suite migrated to the Oberon 90 language.

The implementation was directly derived from the C implementation from https://github.com/rochus-keller/Are-we-fast-yet/tree/main/C
by Rochus Keller supported by Perplexity with the Gemini 2.5 and Claude 4.0 Sonnet models.

The code is currently compatible with Oberon System V4 release 1.7.02.

Here are some preliminary results with the working subset of the benchmarks by 2025-07-22:
![Results](http://software.rochus-keller.ch/awfy_subset_c99_oberon90_2025-07-22.png)
The benchmark was run on an Lenovo T480 under Debian Bookworm x64.
The OP2 compiler of System V4 R1.7 is ~11% faster than unoptimized GCC, and ~3.4 times slower than GCC -O2.


NOTE: this is work in progress, not all benchmarks are migrated yet

