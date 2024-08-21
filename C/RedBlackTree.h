#ifndef _REDBLACKTREE_H
#define _REDBLACKTREE_H

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

#include "som/Interfaces.h"

typedef struct RedBlackTree RedBlackTree;

typedef int (*RedBlackTree_compare)(const Bytes l, const Bytes r); // +1, 0, -1: l>r, l==r, l<r

extern RedBlackTree* RedBlackTree_create(int keySize, int valueSize, RedBlackTree_compare f);

extern void RedBlackTree_dispose(RedBlackTree* me);

extern Bytes RedBlackTree_put(RedBlackTree*, const Bytes key, const Bytes value);

extern Bytes RedBlackTree_remove(RedBlackTree*, const Bytes key);

extern Bytes RedBlackTree_get(RedBlackTree*, const Bytes key);

typedef void (*RedBlackTree_iter)(const Bytes key, const Bytes value, void* data);
extern void RedBlackTree_forEach(RedBlackTree* me, RedBlackTree_iter iter, void* data );


#endif // _REDBLACKTREE_H
