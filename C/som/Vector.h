#ifndef SOM_VECTOR_H
#define SOM_VECTOR_H

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

#include "Interfaces.h"

typedef struct Vector Vector;

extern Vector* Vector_create(int elemSize, int len);

extern Vector* Vector_createDefault(int elemSize);

extern void Vector_dispose(Vector* me);

extern Bytes Vector_at(Vector* me, int idx);

extern void Vector_atPut(Vector* me, int idx, const Bytes val);

extern void Vector_append(Vector* me, const Bytes elem);

extern bool Vector_isEmpty(Vector* me);

extern const Bytes Vector_removeFirst(Vector* me);

extern void Vector_removeAll(Vector* me);

extern int Vector_size(Vector* me);

extern int Vector_capacity(Vector* me);

extern void Vector_forEach(Vector* me, Vector_iter iter, void* data );


#endif // SOM_VECTOR_H
