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

#include "Dictionary.h"
#include <stdlib.h>
#include <memory.h>
#include <assert.h>

typedef struct Entry Entry;

struct Entry {
    int hash;
    Bytes key;
    Bytes value;
    Entry* next; // ref
};

struct Dictionary {
    Entry** buckets; // ref
    int length;
    int sz;
    int keyLen, valueLen;
    Dictionary_hash hash;
};

static Entry* Entry_create(Dictionary* dic, int hash, const Bytes key, const Bytes value, Entry* next) {
    Entry* me = malloc(sizeof(Entry));
    me->hash  = hash;
    me->key   = malloc(dic->keyLen);
    memcpy(me->key, key, dic->keyLen);
    me->value = malloc(dic->valueLen);
    memcpy(me->value, value, dic->valueLen);
    me->next  = next;
    return me;
}

static void Entry_dispose(Entry* me)
{
    if( me == 0 )
        return;
    if( me->next )
        Entry_dispose(me->next);
    free(me->key);
    free(me->value);
    free(me);
}

static bool Entry_match(Entry* me, int hash, const Bytes key, int keyLen) {
    return me->hash == hash && memcmp(key,me->key,keyLen) == 0;
}

enum { INITIAL_CAPACITY = 16 };


Dictionary* Dictionary_create(int keyLen, int valueLen, Dictionary_hash hash) {
    Dictionary* me = malloc(sizeof(Dictionary));
    me->length = INITIAL_CAPACITY;
    me->buckets = calloc(sizeof(Entry*),me->length);
    me->sz = 0;
    me->keyLen = keyLen;
    me->valueLen = valueLen;
    me->hash = hash;
    assert(hash != 0);
    return me;
}

void Dictionary_dispose(Dictionary* me)
{
    for( int i = 0; i < me->length; i++ )
        Entry_dispose(me->buckets[i]);
    free(me->buckets);
    free(me);
}

static int getBucketIdx(Dictionary* me, int hash) {
    return (me->length - 1) & hash;
}

static Entry* getBucket(Dictionary* me, int hash) {
    const int idx = getBucketIdx(me, hash);
    assert(idx < me->length);
    return me->buckets[idx];
}

static int size(Dictionary* me) {
    return me->sz;
}

static bool isEmpty(Dictionary* me) {
    return me->sz == 0;
}

static int hash(Dictionary* me, const Bytes key) {
    const int h = me->hash(key);
    return h ^ ( h >> 16 );
}

static void splitBucket(Dictionary* me, Entry** oldStorage, int oldLen, int i, Entry* head) {
    Entry* loHead = 0;
    Entry* loTail = 0;
    Entry* hiHead = 0;
    Entry* hiTail = 0;
    Entry* current = head;

    while (current!= 0) {
        if ((current->hash & oldLen) == 0) {
            if (loTail == 0) {
                loHead = current;
            } else {
                loTail->next = current;
            }
            loTail = current;
        } else {
            if (hiTail == 0) {
                hiHead = current;
            } else {
                hiTail->next = current;
            }
            hiTail = current;
        }
        current = current->next;
    }

    if (loTail != 0) {
        loTail->next = 0;
        assert(i < me->length);
        me->buckets[i] = loHead;
    }
    if (hiTail != 0) {
        hiTail->next = 0;
        assert(i+oldLen < me->length);
        me->buckets[i + oldLen] = hiHead;
    }
}

static void transferEntries(Dictionary* me, Entry** oldStorage, int oldLen) {
    for (int i = 0; i < oldLen; ++i) {
        Entry* current = oldStorage[i];
        if (current != 0) {
            if (current->next == 0) {
                const int idx = current->hash & (me->length - 1);
                assert(idx < me->length);
                me->buckets[idx] = current;
            } else {
                splitBucket(me, oldStorage, oldLen, i, current);
            }
        }
    }
}

static void insertBucketEntry(Dictionary* me, const Bytes key, const Bytes value, int hash, Entry* head) {
    Entry* current = head;

    while (true) {
        if (Entry_match(current, hash, key, me->keyLen)) {
            free(current->value);
            current->value = malloc(me->valueLen);
            memcpy(current->value,value,me->valueLen);
            return;
        }
        if (current->next == 0) {
            me->sz += 1;
            current->next = Entry_create(me, hash, key, value, 0);
            return;
        }
        current = current->next;
    }
}

static void resize(Dictionary* me) {
    Entry** oldStorage = me->buckets;
    const int oldLen = me->length;

    me->length *= 2;
    Entry** newStorage = calloc(sizeof(Entry*), me->length);
    me->buckets = newStorage;
    transferEntries(me, oldStorage, oldLen);
    free(oldStorage);
}

void Dictionary_removeAll(Dictionary* me) {
    for( int i = 0; i < me->length; i++ ) {
        Entry_dispose(me->buckets[i]);
        me->buckets[i] = 0;
    }
    me->sz = 0;
}

Bytes Dictionary_at(Dictionary* me, const Bytes key) {
    const int h = hash(me, key);
    Entry* e = getBucket(me, h);

    while (e != 0) {
        if (Entry_match(e, h, key, me->keyLen)) {
            return e->value;
        }
        e = e->next;
    }
    return 0;
}

bool Dictionary_containsKey(Dictionary* me, const Bytes key) {
    const int h = hash(me, key);
    Entry* e = getBucket(me, h);

    while (e != 0) {
        if ( Entry_match(e, h, key, me->keyLen)) {
            return true;
        }
        e = e->next;
    }
    return false;
}

void Dictionary_atPut(Dictionary* me, const Bytes key, const Bytes value) {
    const int h = hash(me, key);
    const int i = getBucketIdx(me, h);

    assert( i < me->length );
    Entry* current = me->buckets[i];

    if (current == 0) {
        me->buckets[i] = Entry_create(me, h, key, value, 0);
        me->sz += 1;
    } else {
        insertBucketEntry(me, key, value, h, current);
    }

    if (me->sz > me->length) {
        resize(me);
    }
}

void Dictionary_getKeys(Dictionary* me, Vector* keys) {
    Vector_removeAll(keys);
    Vector_expand(keys, me->sz);
    for (int i = 0; i < me->length; ++i) {
        Entry* current = me->buckets[i];
        while (current != 0) {
            Vector_append(keys, current->key);
            current = current->next;
        }
    }
}

void Dictionary_getValues(Dictionary* me, Vector* values) {
    Vector_removeAll(values);
    Vector_expand(values, me->sz);
    for (int i = 0; i < me->length; ++i) {
        Entry* current = me->buckets[i];
        while (current != 0) {
            Vector_append(values, current->value);
            current = current->next;
        }
    }
}
