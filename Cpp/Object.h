#ifndef _OBJECT_H
#define _OBJECT_H

/* Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch>
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

class Object {
    int refCount;
public:
    Object():refCount(0) {}
    virtual ~Object() {}
    void addRef()
    {
        refCount++;
    }
    void release()
    {
        refCount--;
        if( refCount <= 0 )
            delete this;
    }
};

// #define NO_GC

template <class T>
class Ref
{
    T* obj;
public:
    Ref(T* o = 0):obj(o)
    {
#ifndef NO_GC
        if(obj)
            obj->addRef();
#endif
    }
    Ref( const Ref& rhs ):obj(0)
    {
        *this = rhs;
    }
    ~Ref()
    {
#ifndef NO_GC
        if(obj)
            obj->release();
#endif
    }
    Ref& operator=(T* rhs )
    {
        if( obj == rhs )
            return *this;
#ifndef NO_GC
        if(obj)
            obj->release();
#endif
        obj = rhs;
#ifndef NO_GC
        if( obj )
            obj->addRef();
#endif
        return *this;
    }
    Ref& operator=(const Ref& rhs )
    {
        *this = rhs.obj;
        return *this;
    }
    T* operator->() const { return obj; }
    operator T*() const { return obj; }
    T* ptr() const { return obj; }
};

#endif // _OBJECT_H
