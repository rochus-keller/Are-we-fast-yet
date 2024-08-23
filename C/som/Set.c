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

#include "Set.h"
#include "Vector.h"
#include <stdlib.h>
#include <memory.h>

struct Set {
    Vector* items;
    int elemSize;
};

enum { INITIAL_SIZE = 10 };

Set* Set_create(int elemSize)
{
    Set* me = malloc(sizeof(Set));
    me->items = Vector_createDefault(elemSize);
    me->elemSize = elemSize;
    return me;
}

void Set_dispose(Set* me)
{
    if( me == 0 )
        return;
    Vector_dispose(me->items);
    free(me);
}

int Set_size(Set* me)
{
    if( me == 0 )
        return 0;
    return Vector_size(me->items);
}

void Set_forEach(Set* me, ValueIterator iter, void* data) {
    Vector_forEach(me->items, iter, data);
}

bool Set_hasSome(Set* me, TestIterator iter, void* data) {
    return Vector_hasSome(me->items, iter, data);
}

void Set_removeAll(Set* me) {
    Vector_removeAll(me->items);
}

struct Set_contains_Iter {
    Bytes obj;
    int elemSize;
};

static bool Set_contains_iter(const Bytes value, void* data)
{
    const struct Set_contains_Iter* iter = data;
    return memcmp(value,iter->obj,iter->elemSize);
}

bool Set_contains(Set* me, const Bytes obj) {
    struct Set_contains_Iter iter;
    iter.obj = obj;
    iter.elemSize = me->elemSize;
    return Set_hasSome(me, Set_contains_iter, &iter);
}

void Set_add(Set* me, const Bytes obj) {
    if (!Set_contains(me, obj)) {
        Vector_append(me->items,obj);
    }
}

#if 0

// not used
void collect(CollectInterface<E, E>& fn, Vector<E>& coll) {
    coll.removeAll();

    struct Iterator : public ForEachInterface<E>
    {
        Iterator(CollectInterface<E, E>& f, Vector<E>& c):coll(c),fn(f){}
        Vector<E>& coll;
        CollectInterface<E, E>& fn;
        void apply(const E& e)
        {
            coll.append(fn.collect(e));
        }
    } it(coll);
    forEach(it);
}

#endif
