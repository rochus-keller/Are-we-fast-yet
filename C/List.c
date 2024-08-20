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

#include "List.h"
#include "Object.h"
#include <stdlib.h>

// NOTE:
// with refcount: 77us + no leaks
// without refcount: 68us + some memory leaks
//    in tail() some Element are disposed without delete
// compare with 90us in generated C99 with Boehm GC

typedef struct Element Element;
struct Element {
    Object base;
    int val;
    Element* next;
};

static void Element_setNext(Element* me, Element* e)
{
    Object_release((Object*)me->next);
    me->next = e;
}

static void Element_deinit(Element* me)
{
    Element_setNext(me,0);
}

static Element* Element_create(int v)
{
    // Element_create returns element with refcount set

    Element* e = (Element*)malloc(sizeof(Element));
    Object_init((Object*)e,Element_deinit);
    Object_addRef((Object*)e);
    e->val = v;
    e->next = 0;
    return e;
}

static int Element_length(Element* me)
{
    if (me->next == 0) {
        return 1;
    } else {
        return 1 + Element_length(me->next);
    }
}

static Element* Element_getNext(Element* me)
{
    return me->next;
}

static void Element_setVal(Element* me, int v)
{
    me->val = v;
}

static int Element_getVal(Element* me)
{
    return me->val;
}

static Element* makeList(int length) {
    // makeList returns element with refcount set
    if (length == 0) {
        return 0;
    } else {
        Element* e = Element_create(length);
        Element_setNext(e, makeList(length - 1));
        return e;
    }
}

static bool isShorterThan(Element* x, Element* y) {
    Element* xTail = x;
    Element* yTail = y;

    while (yTail != 0) {
        if (xTail == 0) {
            return true;
        }
        xTail = Element_getNext(xTail);
        yTail = Element_getNext(yTail);
    }
    return false;
}

static Element* tail(Element* x, Element* y, Element* z) {
    // tail returns element with refcount set
    Element* res = 0;
    if (isShorterThan(y, x)) {
        Element* xx = tail(Element_getNext(x), y, z);
        Element* yy = tail(Element_getNext(y), z, x);
        Element* zz = tail(Element_getNext(z), x, y);
        res = tail(xx, yy, zz);
        Object_release((Object*)xx);
        Object_release((Object*)yy);
        Object_release((Object*)zz);
    } else {
        res = z;
        Object_addRef((Object*)z);
    }
    return res;
}

static int benchmark(Benchmark* bench)
{
    Element* x = makeList(15);
    Element* y = makeList(10);
    Element* z = makeList(6);
    Element* result = tail(x, y, z);
    const int res = Element_length(result);
    Object_release((Object*)result);
    Object_release((Object*)x);
    Object_release((Object*)y);
    Object_release((Object*)z);
    return res;
}

static bool verifyResult(Benchmark* bench, int result) {
    return 10 == result;
}

Benchmark* List_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = 0;
    return bench;
}
