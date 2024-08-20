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

#include "Permute.h"
#include <stdlib.h>

typedef struct Permute {
  Benchmark base;
  int count;
  int* v;
} Permute;

static void swap(Permute* me, int i, int j)
{
    int tmp = me->v[i];
    me->v[i] = me->v[j];
    me->v[j] = tmp;
}

static void permute(Permute* me, int n)
{
    me->count++;
    if (n != 0) {
        int n1 = n - 1;
        permute(me, n1);
        for (int i = n1; i >= 0; i--) {
            swap(me, n1, i);
            permute(me, n1);
            swap(me, n1, i);
        }
    }
}

static int benchmark(Permute* me)
{
    me->count = 0;
    me->v     = (int*)calloc(6, sizeof(int));;
    permute(me,6);
    free(me->v);
    return me->count;
}

static bool verifyResult(Permute* me, int result) {
  return result == 8660;
}


Benchmark*Permute_create()
{
    Permute* per = (Permute*)malloc(sizeof(Permute));
    per->base.benchmark = benchmark;
    per->base.verifyResult = verifyResult;
    per->base.dispose = 0;
    per->base.innerBenchmarkLoop = 0;
    return per;
}
