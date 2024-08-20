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

#include "Bounce.h"
#include <stdlib.h>
#include <math.h>
#include "som/Random.h"

typedef struct Ball {
    int x;
    int y;
    int xVel;
    int yVel;
} Ball;


static void Ball_init(Ball* me)
{
    me->x = me->y = me->xVel = me->yVel = 0;
    me->x = Random_next() % 500;
    me->y = Random_next() % 500;
    me->xVel = (Random_next() % 300) - 150;
    me->yVel = (Random_next() % 300) - 150;
}


static bool Ball_bounce(Ball* me) {
    const int xLimit = 500;
    const int yLimit = 500;
    bool bounced = false;

    me->x += me->xVel;
    me->y += me->yVel;
    if (me->x > xLimit) { me->x = xLimit; me->xVel = 0 - abs(me->xVel); bounced = true; }
    if (me->x < 0)      { me->x = 0;      me->xVel = abs(me->xVel);     bounced = true; }
    if (me->y > yLimit) { me->y = yLimit; me->yVel = 0 - abs(me->yVel); bounced = true; }
    if (me->y < 0)      { me->y = 0;      me->yVel = abs(me->yVel);     bounced = true; }
    return bounced;
}

static int benchmark(Benchmark* me)
{
    Random_reset();
    int ballCount = 100;
    int bounces   = 0;

    Ball* balls = (Ball*)calloc(ballCount,sizeof(Ball));
    for (int i = 0; i < ballCount; i++)
        Ball_init(&balls[i]);

    for (int i = 0; i < 50; i++) {
        for (int j = 0; j < ballCount; j++) {
            if (Ball_bounce(&balls[j])) {
                bounces += 1;
            }
        }
    }
    free(balls);
    return bounces;
}

static bool verifyResult(Benchmark* bench, int result) {
    return 1331 == result;
}

Benchmark* Bounce_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
	bench->verifyResult = verifyResult;
	bench->dispose = 0;
    bench->innerBenchmarkLoop = 0;
    return bench;
}
