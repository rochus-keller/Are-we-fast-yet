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

#include "Run.h"
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "Bounce.h"
#include "List.h"
#include "Mandelbrot.h"
#include "Permute.h"
#include "Queens.h"
#include "Sieve.h"
#include "Storage.h"
#include "Towers.h"
#include "NBody.h"
#include "Richards.h"
#include "Json.h"
#include "CD.h"
#include "Havlak.h"
#include "DeltaBlue.h"

jmp_buf Run_catch;

#if defined __ECS_C__ || defined __ECS2_C__
#include <time.h>

typedef struct timeval {
    long tv_sec;
    long tv_usec;
} timeval;

int gettimeofday(struct timeval * tp, struct timezone * tzp)
{
    struct timespec ts;
    timespec_get(&ts,0);
    tp->tv_sec = ts.tv_sec;
    tp->tv_usec = ts.tv_nsec / 1000;
}

#elif defined(_WIN32) && !defined(__GNUC__)
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

// Source: https://stackoverflow.com/questions/10905892/equivalent-of-gettimeday-for-windows/26085827

// MSVC defines this in winsock2.h!?
typedef struct timeval {
    long tv_sec;
    long tv_usec;
} timeval;

int gettimeofday(struct timeval * tp, struct timezone * tzp)
{
    // Note: some broken versions only have 8 trailing zero's, the correct epoch has 9 trailing zero's
    // This magic number is the number of 100 nanosecond intervals since January 1, 1601 (UTC)
    // until 00:00:00 January 1, 1970
    static const uint64_t EPOCH = ((uint64_t) 116444736000000000ULL);

    SYSTEMTIME  system_time;
    FILETIME    file_time;
    uint64_t    time;

    GetSystemTime( &system_time );
    SystemTimeToFileTime( &system_time, &file_time );
    time =  ((uint64_t)file_time.dwLowDateTime )      ;
    time += ((uint64_t)file_time.dwHighDateTime) << 32;

    tp->tv_sec  = (long) ((time - EPOCH) / 10000000L);
    tp->tv_usec = (long) (system_time.wMilliseconds * 1000);
    return 0;
}
#else
#include <sys/time.h>
#endif


Benchmark *Run_getSuiteFromName(const char* name)
{
    if( strcmp(name,"Bounce")== 0 )
        return Bounce_create();
    if( strcmp(name,"List")== 0 )
        return List_create();
    if( strcmp(name,"Mandelbrot")== 0 )
        return Mandelbrot_create();
    if( strcmp(name,"Permute")== 0 )
        return Permute_create();
    if( strcmp(name,"Queens")== 0 )
        return Queens_create();
    if( strcmp(name,"Sieve")== 0 )
        return Sieve_create();
    if( strcmp(name,"Storage")== 0 )
        return Storage_create();
    if( strcmp(name,"Towers")== 0 )
        return Towers_create();
    if( strcmp(name,"NBody")== 0 )
        return NBody_create();
    if( strcmp(name,"Richards")== 0 )
        return Richards_create();
    if( strcmp(name,"Json")== 0 )
        return Json_create();
    if( strcmp(name,"CD")== 0 )
        return CD_create();
    if( strcmp(name,"Havlak")== 0 )
        return Havlak_create();
    if( strcmp(name,"DeltaBlue")== 0 )
        return DeltaBlue_create();
    return 0;
}

void Run_init(Run* me, const char* name)
{
    me->numIterations = 1;
    me->innerIterations = 1;
    me->total = 0;
    me->name = name;
    me->benchmarkSuite = Run_getSuiteFromName(name);
}

void Run_deinit(Run* me)
{
    if( me->benchmarkSuite ) {
        if( me->benchmarkSuite->dispose )
            me->benchmarkSuite->dispose(me->benchmarkSuite);
        free( me->benchmarkSuite );
    }
}

static void printResult(Run* me, long runTime)
{
#if 0
    // Checkstyle: stop
    printf( "%s: iterations=1 runtime: %d us\n", me->name, runTime );
    // Checkstyle: resume
#endif

}

void Run_printTotal(Run* me)
{
#if 0
    // Checkstyle: stop
    printf("Total Runtime: %d us\n", total );
    // Checkstyle: resume
#endif
}

static void measure(Run* me, Benchmark *bench)
{
    struct timeval start, end;
    gettimeofday(&start, 0);
    bool (*innerBenchmarkLoop)(Benchmark*,int innerIterations) = Benchmark_innerBenchmarkLoop;
    if( bench->innerBenchmarkLoop )
        innerBenchmarkLoop = bench->innerBenchmarkLoop;
    if (!innerBenchmarkLoop(bench, me->innerIterations)) {
        printf("Benchmark failed with incorrect result\n");
        return;
    }
    gettimeofday(&end, 0);
    const long seconds = end.tv_sec - start.tv_sec;
    const long microseconds = end.tv_usec - start.tv_usec;
    const long runTime = seconds*1000000 + microseconds; // us

    printResult(me, runTime);

    me->total += runTime;
}

static void doRuns(Run* me, Benchmark *bench)
{
    for (int i = 0; i < me->numIterations; i++) {
        measure(me, bench);
    }
}

static void reportBenchmark(Run* me)
{
    // Checkstyle: stop
    printf("%s: iterations=%d average: %ld us total: %ld us\n",
            me->name, me->numIterations, (me->total / me->numIterations), me->total);
    fflush(stdout);
    // Checkstyle: resume

}

void Run_runBenchmark(Run* me)
{
    if( me->benchmarkSuite == 0 )
    {
        printf("ERROR unknown benchmark %s\n", me->name);
        longjmp(Run_catch,1);
    }

    // Checkstyle: stop
    printf("Starting %s benchmark ...\n", me->name );
    fflush(stdout);
    // Checkstyle: resume

    doRuns(me, me->benchmarkSuite);
    reportBenchmark(me);

    // Checkstyle: stop
    printf("\n");
    // Checkstyle: resume
}

void Run_setNumIterations(Run* me, int numIterations) {
    me->numIterations = numIterations;
}

void Run_setInnerIterations(Run* me, int innerIterations) {
    me->innerIterations = innerIterations;
}

