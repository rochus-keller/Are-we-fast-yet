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

#include "Vector.h"
#include <stdlib.h>
#include <assert.h>
#include <memory.h>

struct Vector {
    int firstIdx;
    int lastIdx;
    int length;
    int elemSize;
    Bytes storage;
};

#if 0

Vector<E>& operator=( const Vector<E>& rhs)
{
    if( length < rhs.lastIdx )
    {
        // not enough space to accommodate rhs
        if( storage )
            delete[] storage;
        if( rhs.length )
            storage = new E[rhs.length];
        else
            storage = 0;
        length = rhs.length;
    }
    firstIdx = rhs.firstIdx;
    lastIdx = rhs.lastIdx;
    if( rhs.length )
    {
        for( int i = firstIdx; i < lastIdx; i++ )
            storage[i] = rhs.storage[i];
    }
    return *this;
}

#endif

static void swap(Bytes storage2, int i, int j) {
    assert(0); // "NotImplemented"
}

static void sort(Vector* me, int i, int j, CompareIterator c, void* data) {
#if 0
    if (c == 0) {
        defaultSort(i, j);
    }
#endif

    int n = j + 1 - i;
    if (n <= 1) {
        return;
    }

    Bytes di = &me->storage[i*me->elemSize];
    Bytes dj = &me->storage[j*me->elemSize];

    if (c(di, dj, data) > 0) {
        swap(me->storage, i, j);
        Bytes tt = di;
        di = dj;
        dj = tt;
    }

    if (n > 2) {
        int ij = (i + j) / 2;
        Bytes dij = &me->storage[ij*me->elemSize];

        if (c(di, dij, data) <= 0) {
            if (c(dij, dj, data) > 0) {
                swap(me->storage, j, ij);
                dij = dj;
            }
        } else {
            swap(me->storage, i, ij);
            dij = di;
        }

        if (n > 3) {
            int k = i;
            int l = j - 1;

            while (true) {
                while (k <= l && c(dij, &me->storage[l*me->elemSize], data) <= 0) {
                    l -= 1;
                }

                k += 1;
                while (k <= l && c( &me->storage[k*me->elemSize], dij, data) <= 0) {
                    k += 1;
                }

                if (k > l) {
                    break;
                }
                swap(me->storage, k, l);
            }

            sort(me, i, l, c, data);
            sort(me, k, j, c, data);
        }
    }
}

void Vector_sort( Vector* me, CompareIterator c, void* data) {
    if (Vector_size(me) > 0) {
        sort(me, me->firstIdx, me->lastIdx - 1, c, data);
    }
}

void Vector_expand(Vector* me, int newLength)
{
    if( newLength <= me->length )
        return;

    if( newLength > 0 )
    {
        me->storage = realloc(me->storage, newLength * me->elemSize);
        memset(me->storage + me->length*me->elemSize, 0, (newLength - me->length) * me->elemSize );
    }
    me->length = newLength;
}

static void enlarge(Vector* me, int idx)
{
    int newLength = me->length;
    while (newLength <= idx) {
        newLength *= 2;
        newLength += 50;
    }
    Vector_expand(me, newLength);
}

Bytes Vector_at(Vector* me, int idx) {
    if (idx < 0 || idx >= me->length) {
        assert(0); // "out of bounds"
    }
    return &me->storage[idx * me->elemSize];
}

void Vector_atPut(Vector* me, int idx, const Bytes val) {
    if (idx >= me->length)
        enlarge(me, idx);
    memcpy(me->storage + idx * me->elemSize, val, me->elemSize);
    if (me->lastIdx < idx + 1) {
        me->lastIdx = idx + 1;
    }
}

void Vector_append(Vector* me, const Bytes elem) {
    if (me->lastIdx >= me->length)
        enlarge(me, me->lastIdx);

    memcpy(me->storage + me->lastIdx * me->elemSize, elem, me->elemSize);
    me->lastIdx++;
}

bool Vector_isEmpty(Vector* me) {
    return me->lastIdx == me->firstIdx;
}

const Bytes Vector_removeFirst(Vector* me) {
    if (Vector_isEmpty(me)) {
        assert(0); // "empty"
    }
    me->firstIdx++;
    return me->storage + (me->firstIdx - 1) * me->elemSize;
}

void Vector_removeAll(Vector* me) {
    me->firstIdx = 0;
    me->lastIdx = 0;
#if 0
    if( me->length )
    {
        delete[] storage;
        storage = new E[length];
    }
#endif
}

int Vector_size(Vector* me) {
    return me->lastIdx - me->firstIdx;
}

int Vector_capacity(Vector* me) {
    return me->length;
}

Vector* Vector_create(int elemSize, int len)
{
    Vector* v = (Vector*)malloc(sizeof(Vector));
    v->elemSize = elemSize;
    v->firstIdx = 0;
    v->lastIdx = 0;
    v->length = 0;
    v->storage = 0;
    Vector_expand(v, len);
    return v;
}

void Vector_dispose(Vector* me)
{
    if( me == 0 )
        return;
    if( me->storage )
        free(me->storage);
    free(me);
}

Vector*Vector_createDefault(int elemSize)
{
    return Vector_create(elemSize,0);
}

void Vector_forEach(Vector* me, ValueIterator iter, void* data)
{
    for (int i = me->firstIdx; i < me->lastIdx; i++) {
        iter(&me->storage[i*me->elemSize], data);
    }
}

bool Vector_hasSome(Vector* me, TestIterator iter, void* data)
{
    for (int i = me->firstIdx; i < me->lastIdx; i++) {
        if (iter(&me->storage[i*me->elemSize], data) ) {
            return true;
        }
    }
    return false;
}

struct Vector_remove_Iterator {
    Bytes newArray;
    int newLast;
    Bytes obj;
    int elemSize;
    bool found;
};

static void Vector_remove_iter(const Bytes value, void* data) {
    struct Vector_remove_Iterator* me = data;
    if ( memcmp(value, me->obj, me->elemSize) == 0 ) {
        me->found = true;
    } else {
        memcpy(me->newArray + me->newLast*me->elemSize, value, me->elemSize);
        me->newLast++;
    }
}

bool Vector_remove(Vector* me, const Bytes obj) {
    if( me->length == 0 )
        return false;

    Bytes newArray = malloc(me->length*me->elemSize);

    struct Vector_remove_Iterator iter;
    iter.newArray = newArray;
    iter.found = false;
    iter.obj = obj;
    iter.newLast = 0;
    iter.elemSize = me->elemSize;

    Vector_forEach(me, Vector_remove_iter, &iter);

    free(me->storage);
    me->storage  = newArray;
    me->lastIdx  = iter.newLast;
    me->firstIdx = 0;
    return iter.found;
}

Vector* Vector_copy(Vector* in)
{
    Vector* me = Vector_create(in->elemSize,in->length);
    me->firstIdx = in->firstIdx;
    me->lastIdx = in->lastIdx;
    memcpy(me->storage, in->storage, in->length * in->elemSize);
    return me;
}
