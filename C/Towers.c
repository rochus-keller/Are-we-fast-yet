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

#include "Towers.h"
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>

typedef struct TowersDisk TowersDisk;

struct TowersDisk {
    int size;
    TowersDisk* next;
};

enum { PilesCount = 3 };

typedef struct Towers {
    Benchmark base;
    TowersDisk* piles[PilesCount];
    int movesDone;

} Towers;

static void TowersDisk_dispose(TowersDisk* me)
{
    if( me->next )
        TowersDisk_dispose(me->next);
    free(me);
}

static TowersDisk* TowersDisk_create(int size)
{
    TowersDisk* d = (TowersDisk*)malloc(sizeof(TowersDisk));
    d->next = 0;
    d->size = size;
    return d;
}

static int TowersDisk_getSize(TowersDisk* me) { return me->size;  }

static TowersDisk* TowersDisk_getNext(TowersDisk* me){ return me->next;  }

static void TowersDisk_setNext(TowersDisk* me, TowersDisk* value) { me->next = value; }


static void pushDisk(Towers* me, TowersDisk *disk, int pile)
{
    TowersDisk* top = me->piles[pile];
    if (!(top == 0) && (TowersDisk_getSize(disk) >= TowersDisk_getSize(top))) {
        assert(0); // "Cannot put a big disk on a smaller one"
    }

    TowersDisk_setNext(disk,top);
    me->piles[pile] = disk;
}

static TowersDisk *popDiskFrom(Towers* me, int pile)
{
    TowersDisk* top = me->piles[pile];
    if (top == 0) {
        assert(0); // "Attempting to remove a disk from an empty pile"
    }

    me->piles[pile] = TowersDisk_getNext(top);
    TowersDisk_setNext(top,0);
    return top;
}

static void moveTopDisk(Towers* me, int fromPile, int toPile)
{
    pushDisk(me,popDiskFrom(me,fromPile), toPile);
    me->movesDone++;
}

static void buildTowerAt(Towers* me, int pile, int disks)
{
    for (int i = disks; i >= 0; i--) {
        pushDisk(me, TowersDisk_create(i), pile);
    }
}

static void moveDisks(Towers* me, int disks, int fromPile, int toPile)
{
    if (disks == 1) {
        moveTopDisk(me, fromPile, toPile);
    } else {
        const int otherPile = (3 - fromPile) - toPile;
        moveDisks(me, disks - 1, fromPile, otherPile);
        moveTopDisk(me, fromPile, toPile);
        moveDisks(me, disks - 1, otherPile, toPile);
    }
}

static int benchmark(Towers* me)
{
    for( int i = 0; i < PilesCount; i++ )
        me->piles[i] = 0;
    buildTowerAt(me, 0, 13);
    me->movesDone = 0;
    moveDisks(me, 13, 0, 1);
    for( int i = 0; i < PilesCount; i++ )
        if( me->piles[i] )
            TowersDisk_dispose(me->piles[i]);
    return me->movesDone;
}

static bool verifyResult(Benchmark* me, int result) {
    return 8191 == result;
}

Benchmark*Towers_create()
{
    Towers* t = (Towers*)malloc(sizeof(Towers));
    t->base.benchmark = benchmark;
    t->base.verifyResult = verifyResult;
    t->base.dispose = 0;
    t->base.innerBenchmarkLoop = 0;
    return t;
}
