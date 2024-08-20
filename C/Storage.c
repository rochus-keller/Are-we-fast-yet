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

#include "Storage.h"
#include "som/Random.h"
#include <stdbool.h>
#include <stdlib.h>

typedef struct Storage {
  Benchmark base;
  int count;

} Storage;

typedef struct Tree Tree;

typedef struct TreeArray
{
    Tree* arr;
    int len;
} TreeArray;

struct Tree
{
    TreeArray subs;
};

static void freeTree(TreeArray* ta)
{
    for( int i = 0; i < ta->len; i++ )
    {
        Tree* t = &ta->arr[i];
        freeTree(&t->subs);
    }
    free(ta->arr);
    ta->len = 0;
    ta->arr = 0;
}

static TreeArray buildTreeDepth(Storage* me, int depth)
{
    me->count++;
    if (depth == 1) {
        TreeArray res;
        res.len = Random_next() % 10 + 1;
        res.arr = (Tree*)calloc(res.len,sizeof(Tree));
        return res;
    } else {
        TreeArray res;
        res.len = 4;
        res.arr = (Tree*)calloc(res.len,sizeof(Tree));
        for( int i = 0; i < res.len; i++ )
            res.arr[i].subs = buildTreeDepth(me, depth - 1);
        return res;
    }
}

static int benchmark(Storage* me)
{
    Random_reset();
    me->count = 0;
    TreeArray arr = buildTreeDepth(me, 7);
    freeTree(&arr);
    return me->count;
}

static bool verifyResult(Benchmark* me, int result) {
  return 5461 == result;
}

Benchmark*Storage_create()
{
    Storage* s = (Storage*)malloc(sizeof(Storage));
    s->base.benchmark = benchmark;
    s->base.verifyResult = verifyResult;
    s->base.dispose = 0;
    s->base.innerBenchmarkLoop = 0;
    return s;
}
