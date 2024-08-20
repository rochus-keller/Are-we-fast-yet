#ifndef _RUN_H
#define _RUN_H

/* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the 'Software'), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <Benchmark.h>
#include <setjmp.h>

typedef struct Run {
    const char* name;
    Benchmark* benchmarkSuite;
    int numIterations;
    int innerIterations;
    long total;
} Run;

extern void Run_init(Run* me, const char* name);
extern void Run_deinit(Run* me);
extern void Run_runBenchmark(Run* me);
extern void Run_printTotal(Run* me);
extern void Run_setNumIterations(Run* me, int numIterations);
extern void Run_setInnerIterations(Run* me, int innerIterations);


extern Benchmark* Run_getSuiteFromName(const char* name);

extern jmp_buf Run_catch;


#endif // _RUN_H
