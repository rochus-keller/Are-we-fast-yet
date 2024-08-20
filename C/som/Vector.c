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


void forEach(ForEachInterface<E>& fn) {
    for (int i = firstIdx; i < lastIdx; i++) {
        fn.apply(storage[i]);
    }
}

bool hasSome(TestInterface<E>& fn) const {
    for (int i = firstIdx; i < lastIdx; i++) {
        if (fn.test(storage[i])) {
            return true;
        }
    }
    return false;
}

bool remove(const E& obj) {
    if( length == 0 )
        return false;

    E* newArray = new E[length];

    struct Iterator : public ForEachInterface<E>
    {
        Iterator(E* a, const E* o):newArray(a),newLast(0),found(false),obj(o){}
        E* newArray;
        int newLast;
        const E* obj;
        bool found;
        void apply(const E& it)
        {
            if (it == *obj) {
                found = true;
            } else {
                newArray[newLast] = it;
                newLast++;
            }
        }
    } it(newArray, &obj);
    forEach(it);

    delete[] storage;
    storage  = newArray;
    lastIdx  = it.newLast;
    firstIdx = 0;
    return it.found;
}

void sort( const Comparator<E>& c) {
    if (size() > 0) {
        sort(firstIdx, lastIdx - 1, c);
    }
}

void sort(int i, int j, const Comparator<E>& c) {
#if 0
    if (c == 0) {
        defaultSort(i, j);
    }
#endif

    int n = j + 1 - i;
    if (n <= 1) {
        return;
    }

    E di = storage[i];
    E dj = storage[j];

    if (c.compare(di, dj) > 0) {
        swap(storage, i, j);
        E tt = di;
        di = dj;
        dj = tt;
    }

    if (n > 2) {
        int ij = (i + j) / 2;
        E dij = storage[ij];

        if (c.compare(di, dij) <= 0) {
            if (c.compare(dij, dj) > 0) {
                swap(storage, j, ij);
                dij = dj;
            }
        } else {
            swap(storage, i, ij);
            dij = di;
        }

        if (n > 3) {
            int k = i;
            int l = j - 1;

            while (true) {
                while (k <= l && c.compare(dij, storage[l]) <= 0) {
                    l -= 1;
                }

                k += 1;
                while (k <= l && c.compare( storage[k], dij) <= 0) {
                    k += 1;
                }

                if (k > l) {
                    break;
                }
                swap(storage, k, l);
            }

            sort(i, l, c);
            sort(k, j, c);
        }
    }
}


#endif

static void expand(Vector* me, int newLength)
{
    if( newLength <= me->length )
        return;

    if( newLength > 0 )
    {
        me->storage = realloc(me->storage, newLength * me->elemSize);
        memset(me->storage + me->length, 0, newLength - me->length);
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
    expand(me, newLength);
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
    v->length = len;
    v->storage = 0;
    expand(v, len);
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

void Vector_forEach(Vector* me, Vector_iter iter, void* data)
{
    for (int i = me->firstIdx; i < me->lastIdx; i++) {
        iter(&me->storage[i*me->elemSize], data);
    }
}
