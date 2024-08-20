/* The Computer Language Benchmarks Game
 * http://shootout.alioth.debian.org/
 *
 * Based on nbody.java and adapted based on the SOM version.
 * Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 */

#include "NBody.h"
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#define PI  3.141592653589793
#define SOLAR_MASS (4 * PI * PI)
#define DAYS_PER_YER 365.24

typedef struct Body {
    double x;
    double y;
    double z;
    double vx;
    double vy;
    double vz;
    double mass;
} Body;

static double Body_getX(Body* me) { return me->x; }
static double Body_getY(Body* me) { return me->y; }
static double Body_getZ(Body* me) { return me->z; }

static double Body_getVX(Body* me) { return me->vx; }
static double Body_getVY(Body* me) { return me->vy; }
static double Body_getVZ(Body* me) { return me->vz; }

static double Body_getMass(Body* me) { return me->mass; }

static void Body_setX(Body* me, double x) { me->x = x; }
static void Body_setY(Body* me, double y) { me->y = y; }
static void Body_setZ(Body* me, double z) { me->z = z; }

static void Body_setVX(Body* me, double vx) { me->vx = vx; }
static void Body_setVY(Body* me, double vy) { me->vy = vy; }
static void Body_setVZ(Body* me, double vz) { me->vz = vz; }

static void Body_offsetMomentum(Body* me, double px, double py, double pz) {
    me->vx = 0.0 - (px / SOLAR_MASS);
    me->vy = 0.0 - (py / SOLAR_MASS);
    me->vz = 0.0 - (pz / SOLAR_MASS);
}

Body Body_create(double x, double y, double z,
     double vx, double vy, double vz, double mass) {
    Body res;
    Body* me = &res;
    me->x = x;
    me->y = y;
    me->z = z;
    me->vx = vx * DAYS_PER_YER;
    me->vy = vy * DAYS_PER_YER;
    me->vz = vz * DAYS_PER_YER;
    me->mass = mass * SOLAR_MASS;
    return res;
}

static Body Body_jupiter() {
    return Body_create(
                4.84143144246472090e+00,
                -1.16032004402742839e+00,
                -1.03622044471123109e-01,
                1.66007664274403694e-03,
                7.69901118419740425e-03,
                -6.90460016972063023e-05,
                9.54791938424326609e-04);
}

static Body Body_saturn() {
    return Body_create(
                8.34336671824457987e+00,
                4.12479856412430479e+00,
                -4.03523417114321381e-01,
                -2.76742510726862411e-03,
                4.99852801234917238e-03,
                2.30417297573763929e-05,
                2.85885980666130812e-04);
}

static Body Body_uranus() {
    return Body_create(
                1.28943695621391310e+01,
                -1.51111514016986312e+01,
                -2.23307578892655734e-01,
                2.96460137564761618e-03,
                2.37847173959480950e-03,
                -2.96589568540237556e-05,
                4.36624404335156298e-05);
}

static Body Body_neptune() {
    return Body_create(
                1.53796971148509165e+01,
                -2.59193146099879641e+01,
                1.79258772950371181e-01,
                2.68067772490389322e-03,
                1.62824170038242295e-03,
                -9.51592254519715870e-05,
                5.15138902046611451e-05);
}

static Body Body_sun() {
    return Body_create(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
}

enum { Count = 5 };

typedef struct NBodySystem {
    Body bodies[Count];
} NBodySystem;

static void NBodySystem_init(NBodySystem* me) {
    me->bodies[0] = Body_sun();
    me->bodies[1] = Body_jupiter();
    me->bodies[2] = Body_saturn();
    me->bodies[3] = Body_uranus();
    me->bodies[4] = Body_neptune();

    double px = 0.0;
    double py = 0.0;
    double pz = 0.0;

    for ( int i = 0; i < Count; i++ ) {
        Body* b = &me->bodies[i];
        px += Body_getVX(b) * Body_getMass(b);
        py += Body_getVY(b) * Body_getMass(b);
        pz += Body_getVZ(b) * Body_getMass(b);
    }

    Body_offsetMomentum(&me->bodies[0], px, py, pz);
}

static void NBodySystem_advance(NBodySystem* me, double dt) {

    for (int i = 0; i < Count; ++i) {
        Body* iBody = &me->bodies[i];

        for (int j = i + 1; j < Count; ++j) {
            Body* jBody = &me->bodies[j];
            const double dx = Body_getX(iBody) - Body_getX(jBody);
            const double dy = Body_getY(iBody) - Body_getY(jBody);
            const double dz = Body_getZ(iBody) - Body_getZ(jBody);

            const double dSquared = dx * dx + dy * dy + dz * dz;
            const double distance = sqrt(dSquared);
            const double mag = dt / (dSquared * distance);

            Body_setVX(iBody, Body_getVX(iBody) - (dx * Body_getMass(jBody) * mag));
            Body_setVY(iBody, Body_getVY(iBody) - (dy * Body_getMass(jBody) * mag));
            Body_setVZ(iBody, Body_getVZ(iBody) - (dz * Body_getMass(jBody) * mag));

            Body_setVX(jBody, Body_getVX(jBody) + (dx * Body_getMass(iBody) * mag));
            Body_setVY(jBody, Body_getVY(jBody) + (dy * Body_getMass(iBody) * mag));
            Body_setVZ(jBody, Body_getVZ(jBody) + (dz * Body_getMass(iBody) * mag));
        }
    }

    for (int i = 0; i < Count; i++) {
        Body* body = &me->bodies[i];
        Body_setX(body, Body_getX(body) + dt * Body_getVX(body));
        Body_setY(body, Body_getY(body) + dt * Body_getVY(body));
        Body_setZ(body, Body_getZ(body) + dt * Body_getVZ(body));
    }
}

static double NBodySystem_energy(NBodySystem* me) {
    double e = 0.0;

    for (int i = 0; i < Count; ++i) {
        Body* iBody = &me->bodies[i];
        e += 0.5 * Body_getMass(iBody)
                * (Body_getVX(iBody) * Body_getVX(iBody) +
                   Body_getVY(iBody) * Body_getVY(iBody) +
                   Body_getVZ(iBody) * Body_getVZ(iBody));

        for (int j = i + 1; j < Count; ++j) {
            Body* jBody = &me->bodies[j];
            const double dx = Body_getX(iBody) - Body_getX(jBody);
            const double dy = Body_getY(iBody) - Body_getY(jBody);
            const double dz = Body_getZ(iBody) - Body_getZ(jBody);

            const double distance = sqrt(dx * dx + dy * dy + dz * dz);
            e -= (Body_getMass(iBody) * Body_getMass(jBody)) / distance;
        }
    }
    return e;
}

static bool verifyResult2(double result, int innerIterations)
{
    const double epsilon = 0.00000000000000005; // 5e-17
    if (innerIterations == 250000) {
        return abs(result) - 0.1690859889909308 < epsilon;
    }
    if (innerIterations == 1) {
        return abs(result) - 0.16907495402506745 < epsilon;
    }

    // Checkstyle: stop
    fprintf(stderr,"No verification result for %d found\n", innerIterations);
    fprintf(stderr,"Result is: %f\n", result);
    // Checkstyle: resume
    return false;
}

static bool innerBenchmarkLoop(Benchmark* me, int innerIterations)
{
    NBodySystem system;
    NBodySystem_init(&system);
    for (int i = 0; i < innerIterations; i++) {
        NBodySystem_advance(&system,0.01);
    }

    return verifyResult2(NBodySystem_energy(&system), innerIterations);
}

static int benchmark(Benchmark* me) {
    assert(0); // "Should never be reached"
}

static bool verifyResult(Benchmark* me, int result) {
    assert(0); // "Should never be reached"
}


Benchmark*NBody_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = innerBenchmarkLoop;
    return bench;
}
