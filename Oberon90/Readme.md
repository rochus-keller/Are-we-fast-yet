This is a version of the "Are We Fast Yet?" benchmark suite migrated to the Oberon 90 language.

The implementation was directly derived from the C implementation from https://github.com/rochus-keller/Are-we-fast-yet/tree/main/C
by Rochus Keller supported by Perplexity with the Gemini 2.5 and Claude 4.0 Sonnet models.

NOTE: this is work in progress, not all benchmarks are migrated yet

The code is currently compatible with Oberon System V4 release 1.7.02.

Currently, the following benchmarks are known to work: Richards, Bounce, List, Mandelbrot, Permute, Queens, Sieve, and Storage.
Pending: NBody and Towers were migrated and successfully tested in the Oberon+ IDE, but crash when compiled with OP2.

See the Results directory for performance measurement results.



