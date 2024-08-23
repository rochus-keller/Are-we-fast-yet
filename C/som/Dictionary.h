#ifndef SOM_DICTIONARY_H
#define SOM_DICTIONARY_H

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

typedef struct Dictionary Dictionary;
typedef Dictionary IdentityDictionary;

typedef int (*Dictionary_hash)(const Bytes key);

extern Dictionary* Dictionary_create(int keyLen, int valueLen, Dictionary_hash hash);

extern void Dictionary_dispose(Dictionary* me);

extern void Dictionary_removeAll(Dictionary* me);

extern Bytes Dictionary_at(Dictionary* me, const Bytes key);

extern bool Dictionary_containsKey(Dictionary* me, const Bytes key);

extern void Dictionary_atPut(Dictionary* me, const Bytes key, const Bytes value);

extern void Dictionary_getKeys(Dictionary* me, Vector* keys);

extern void Dictionary_getValues(Dictionary* me, Vector* values);

#endif // SOM_DICTIONARY_H
