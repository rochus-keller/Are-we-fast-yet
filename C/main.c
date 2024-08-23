/* Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch>
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
#include <assert.h>
#include <stdio.h>
#include "RedBlackTree.h"
#include "som/Dictionary.h"

static int compare(const Bytes l, const Bytes r)
{
    int* lhs = l;
    int* rhs = r;
    if( *lhs < *rhs)
        return -1;
    else if( *lhs > *rhs )
        return 1;
    else
        return 0;
}

static void iter(const Bytes key, const Bytes value, void* data)
{
    int* k = key;
    double* v = value;
    printf("key=%d, value=%f\n", *k, *v);
}

static void testrb()
{
    RedBlackTree* t = RedBlackTree_create(sizeof(int),sizeof(double),compare);
    int key;
    double value;

    key = 3; value = 3.456;
    RedBlackTree_put(t, &key, &value);
    key = 2; value = 2.345;
    RedBlackTree_put(t, &key, &value);
    key = 5; value = 5.678;
    RedBlackTree_put(t, &key, &value);

    double* res;
    key = 2; value = 1.234;
    res = RedBlackTree_put(t, &key, &value);


    key = 9;
    res = RedBlackTree_get(t,&key);
    key = 3;
    res = RedBlackTree_get(t,&key);

    RedBlackTree_forEach(t, iter, 0);

    RedBlackTree_dispose(t);
}

static int hash(const Bytes key)
{
    int* k = key;
    return *k;
}

static void testdic()
{
    Dictionary* t = Dictionary_create(sizeof(int),sizeof(double),hash);
    int key;
    double value;

    double* res;

    key = 3; value = 3.456;
    Dictionary_atPut(t, &key, &value);
    key = 2; value = 2.345;
    Dictionary_atPut(t, &key, &value);
    key = 5; value = 5.678;
    Dictionary_atPut(t, &key, &value);

    key = 2; value = 1.234;
    Dictionary_atPut(t, &key, &value);


    for( int i = 10; i < 30; i++ ) {
        value = i;
        Dictionary_atPut(t, &i, &value);
    }

    key = 9;
    res = Dictionary_at(t,&key);
    key = 3;
    res = Dictionary_at(t,&key);
    key = 2;
    res = Dictionary_at(t,&key);

    Vector* keys = Vector_createDefault(sizeof(int));
    Dictionary_getKeys(t, keys);

    Vector* vals = Vector_createDefault(sizeof(double));
    Dictionary_getValues(t, vals);

    assert(Vector_size(keys) == Vector_size(vals));

    for( int i = 0; i < Vector_size(keys); i++ )
        printf("key=%d val=%f\n", *(int*)Vector_at(keys,i), *(double*)Vector_at(vals,i) );

    Vector_dispose(keys);
    Vector_dispose(vals);
    Dictionary_dispose(t);
}

static void run( const char* what, int numIterations, int innerIterations )
{
    Run r;
    Run_init(&r,what);
    Run_setNumIterations(&r, numIterations);
    Run_setInnerIterations(&r, innerIterations);

    if( setjmp(Run_catch) == 0 )
    {
        Run_runBenchmark(&r);
        Run_printTotal(&r);
    }
    Run_deinit(&r);
}

static void runAll()
{
    run("DeltaBlue", 12000, 1 );
    run("Richards", 100, 1);
    run("Json", 100, 1);
    run("Havlak", 10, 1 );
    run("CD", 250, 2);
    run("Bounce", 1500, 1);
    run("List", 1500, 1);
    run("Mandelbrot", 500, 1);
    run("NBody", 250000, 1);
    run("Permute", 1000, 1);
    run("Queens", 1000, 1);
    run("Sieve", 3000, 1);
    run("Storage", 1000, 1);
    run("Towers", 600, 1);
}

static void runOnce()
{
    run("DeltaBlue", 1, 1 );
    run("Richards", 1, 1);
    run("Json", 1, 1);
    run("Havlak", 1, 1 );
    run("CD", 1, 2);
    run("Bounce", 1, 1);
    run("List", 1, 1);
    run("Mandelbrot", 1, 1);
    run("NBody", 1, 1);
    run("Permute", 1, 1);
    run("Queens", 1, 1);
    run("Sieve", 1, 1);
    run("Storage", 1, 1);
    run("Towers", 1, 1);
}

int main(int argc, char *argv[])
{
    runAll();
    //runOnce();

    return 0;
}
