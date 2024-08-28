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

#include "Queens.h"
#include <stdbool.h>
#include <stdlib.h>

typedef struct Queens {
    Benchmark base;
    bool* freeMaxs;
    bool* freeRows;
    bool* freeMins;
    int*     queenRows;
} Queens;

static bool getRowColumn(Queens* me, int r, int c)
{
    return me->freeRows[r] && me->freeMaxs[c + r] && me->freeMins[c - r + 7];
}

static void setRowColumn(Queens* me, int r, int c, bool v)
{
    me->freeRows[r        ] = v;
    me->freeMaxs[c + r    ] = v;
    me->freeMins[c - r + 7] = v;
}

static bool placeQueen(Queens* me, int c)
{
    for (int r = 0; r < 8; r++) {
      if (getRowColumn(me, r, c)) {
        me->queenRows[r] = c;
        setRowColumn(me, r, c, false);

        if (c == 7) {
          return true;
        }

        if (placeQueen(me, c + 1)) {
          return true;
        }
        setRowColumn(me, r, c, true);
      }
    }
    return false;
}

static bool queens(Queens* me)
{
    me->freeRows  = (bool*)calloc(8,1);
    me->freeMaxs  = (bool*)calloc(16,1);
    me->freeMins  = (bool*)calloc(16,1);
    me->queenRows = (int*)calloc(8,4);

    for( int i = 0; i < 8; i++ )
    {
        me->freeRows[i] = true;
        me->queenRows[i] = -1;
    }
    for( int i = 0; i < 16; i++ )
    {
        me->freeMaxs[i] = true;
        me->freeMins[i] = true;
    }

    const bool res = placeQueen(me, 0);

    free(me->freeRows);
    free(me->freeMaxs);
    free(me->freeMins);
    free(me->queenRows);

    return res;
}

static int benchmark(Queens* me)
{
    bool result = true;
    for (int i = 0; i < 10; i++) {
      result = result && queens(me);
    }
    return result;
}

static bool verifyResult(Benchmark* me, int result) {
    return result != 0;
}

Benchmark*Queens_create()
{
    Queens* q = (Queens*)malloc(sizeof(Queens));
    q->base.benchmark = benchmark;
    q->base.verifyResult = verifyResult;
    q->base.dispose = 0;
    q->base.innerBenchmarkLoop = 0;
    return q;
}
