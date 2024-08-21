/*
 * Copyright (c) 2001-2016 Stefan Marr
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

#include "CD.h"
#include "RedBlackTree.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "som/Vector.h"
#include <assert.h>

#define USE_FANCY_ITERATORS
/* NOTE: virtually no difference with or without iterators.
 * With define 1885 us, withour 1851 us
 */

typedef struct Vector2D {
    double x;
    double y;
} Vector2D;

Vector2D Vector2D_create(double x, double y) {
    Vector2D me;
    me.x = x;
    me.y = y;
    return me;
}

Vector2D Vector2D_plus(Vector2D me, Vector2D other) {
    return Vector2D_create(me.x + other.x,
                    me.y + other.y);
}

Vector2D Vector2D_minus(Vector2D me, Vector2D other) {
    return Vector2D_create(me.x - other.x,
                    me.y - other.y);
}

static int compareNumbers( double a,  double b) {
    if (a == b) {
        return 0;
    }
    if (a < b) {
        return -1;
    }
    if (a > b) {
        return 1;
    }

    // We say that NaN is smaller than non-NaN.
    if (a == a) {
        return 1;
    }
    return -1;
}

static int Vector2D_compare(const Bytes l, const Bytes o) {
    const Vector2D* lhs = l;
    const Vector2D* other = o;
    int result = compareNumbers(lhs->x, other->x);
    if (result != 0) {
        return result;
    }
    return compareNumbers(lhs->y, other->y);
}

typedef struct Vector3D {
    double x;
    double y;
    double z;
} Vector3D;

static Vector3D Vector3D_create( double x,  double y,  double z) {
    Vector3D me;
    me.x = x;
    me.y = y;
    me.z = z;
    return me;
}

static Vector3D Vector3D_plus(Vector3D me, Vector3D other) {
    return Vector3D_create(me.x + other.x,
                        me.y + other.y,
                        me.z + other.z);
}

static Vector3D Vector3D_minus(Vector3D me, Vector3D other) {
    return Vector3D_create(me.x - other.x,
                        me.y - other.y,
                        me.z - other.z);
}

static double Vector3D_dot(Vector3D me, const Vector3D other) {
    return me.x * other.x + me.y * other.y + me.z * other.z;
}

static double Vector3D_squaredMagnitude(Vector3D me) {
    return Vector3D_dot(me, me);
}

static double Vector3D_magnitude(Vector3D me) {
    return sqrt(Vector3D_squaredMagnitude(me));
}

static Vector3D Vector3D_times( Vector3D me, double amount) {
    return Vector3D_create(me.x * amount,
                        me.y * amount,
                        me.z * amount);
}

typedef struct CallSign {
    int value;
} CallSign;

static CallSign CallSign_create(int value)
{
    CallSign me;
    me.value = value;
    return me;
}

static int CallSign_compare(const Bytes l, const Bytes o)
{
    const CallSign* lhs = l;
    const CallSign* other = o;
    return (lhs->value == other->value) ? 0 : ((lhs->value < other->value) ? -1 : 1);
}

typedef struct Aircraft {
    CallSign callsign;
    Vector3D position;
} Aircraft;

static Aircraft Aircraft_create(const CallSign* callsign, Vector3D position) {
    Aircraft me;
    me.callsign = *callsign;
    me.position = position;
    return me;
}

typedef struct Collision {
    CallSign aircraftA;
    CallSign aircraftB;
    Vector3D position;
} Collision;

static Collision Collision_create(CallSign aircraftA, CallSign aircraftB, Vector3D position) {
    Collision me;
    me.aircraftA = aircraftA;
    me.aircraftB = aircraftB;
    me.position = position;
    return me;
}

typedef struct Motion {
    CallSign callsign;
    Vector3D posOne;
    Vector3D posTwo;
} Motion;

static Motion Motion_create( CallSign callsign, Vector3D posOne, Vector3D posTwo) {
    Motion me;
    me.callsign = callsign;
    me.posOne = posOne;
    me.posTwo = posTwo;
    return me;
}

Vector3D Motion_delta(Motion* me) {
    return Vector3D_minus(me->posTwo, me->posOne);
}

#define MIN_X  0.0
#define MIN_Y  0.0
#define MAX_X  1000.0
#define MAX_Y  1000.0
#define MIN_Z  0.0
#define MAX_Z  10.0
#define PROXIMITY_RADIUS 1.0
#define GOOD_VOXEL_SIZE  (PROXIMITY_RADIUS * 2.0)

static bool Motion_findIntersection(Motion* me, Motion* other, Vector3D* result) {
    Vector3D init1 = me->posOne;
    Vector3D init2 = other->posOne;
    Vector3D vec1 = Motion_delta(me);
    Vector3D vec2 = Motion_delta(other);
    const double radius = PROXIMITY_RADIUS;

    // this test is not geometrical 3-d intersection test, it takes the fact that the aircraft move
    // into account ; so it is more like a 4d test
    // (it assumes that both of the aircraft have a constant speed over the tested interval)

    // we thus have two points, each of them moving on its line segment at constant speed ; we are looking
    // for times when the distance between these two points is smaller than r

    // vec1 is vector of aircraft 1
    // vec2 is vector of aircraft 2

    // a = (V2 - V1)^T * (V2 - V1)
    double a = Vector3D_squaredMagnitude(Vector3D_minus(vec2, vec1));

    if (a != 0.0) {
        // we are first looking for instances of time when the planes are exactly r from each other
        // at least one plane is moving ; if the planes are moving in parallel, they do not have constant speed

        // if the planes are moving in parallel, then
        //   if the faster starts behind the slower, we can have 2, 1, or 0 solutions
        //   if the faster plane starts in front of the slower, we can have 0 or 1 solutions

        // if the planes are not moving in parallel, then

        // point P1 = I1 + vV1
        // point P2 = I2 + vV2
        //   - looking for v, such that dist(P1,P2) = || P1 - P2 || = r

        // it follows that || P1 - P2 || = sqrt( < P1-P2, P1-P2 > )
        //   0 = -r^2 + < P1 - P2, P1 - P2 >
        //  from properties of dot product
        //   0 = -r^2 + <I1-I2,I1-I2> + v * 2<I1-I2, V1-V2> + v^2 *<V1-V2,V1-V2>
        //   so we calculate a, b, c - and solve the quadratic equation
        //   0 = c + bv + av^2

        // b = 2 * <I1-I2, V1-V2>
        double b = 2.0 * Vector3D_dot(Vector3D_minus(init1,init2), Vector3D_minus(vec1,vec2));

        // c = -r^2 + (I2 - I1)^T * (I2 - I1)
        double c = -radius * radius + Vector3D_squaredMagnitude(Vector3D_minus(init2, init1));

        double discr = b * b - 4.0 * a * c;
        if (discr < 0.0) {
            return false;
        }

        double v1 = (-b - sqrt(discr)) / (2.0 * a);
        double v2 = (-b + sqrt(discr)) / (2.0 * a);

        if (v1 <= v2 && ((v1  <= 1.0 && 1.0 <= v2) ||
                         (v1  <= 0.0 && 0.0 <= v2) ||
                         (0.0 <= v1  && v2  <= 1.0))) {
            // Pick a good "time" at which to report the collision.
            double v;
            if (v1 <= 0.0) {
                // The collision started before this frame. Report it at the start of the frame.
                v = 0.0;
            } else {
                // The collision started during this frame. Report it at that moment.
                v = v1;
            }

            Vector3D result1 = Vector3D_plus(init1, Vector3D_times(vec1, v));
            Vector3D result2 = Vector3D_plus(init2, Vector3D_times(vec2, v));

            *result = Vector3D_times(Vector3D_plus(result1, result2),0.5);
            if (result->x >= MIN_X &&
                    result->x <= MAX_X &&
                    result->y >= MIN_Y &&
                    result->y <= MAX_Y &&
                    result->z >= MIN_Z &&
                    result->z <= MAX_Z) {
                return true;
            }
        }

        return false;
    }

    // the planes have the same speeds and are moving in parallel (or they are not moving at all)
    // they  thus have the same distance all the time ; we calculate it from the initial point

    // dist = || i2 - i1 || = sqrt(  ( i2 - i1 )^T * ( i2 - i1 ) )
    double dist = Vector3D_magnitude(Vector3D_minus(init2,init1));
    if (dist <= radius) {
        *result = Vector3D_times(Vector3D_plus(init1, init2),0.5);
        return true;
    }

    return false;
}

static const Vector2D horizontal = { GOOD_VOXEL_SIZE, 0.0 };
static const Vector2D vertical = { 0.0, GOOD_VOXEL_SIZE };

typedef struct CollisionDetector {
    RedBlackTree* state; // RedBlackTree<CallSign, Vector3D, CallSign::Compare>
} CollisionDetector;

static void CollisionDetector_init(CollisionDetector* me) {
    me->state = RedBlackTree_create(sizeof(CallSign), sizeof(Vector3D), CallSign_compare);
}

void CollisionDetector_deinit(CollisionDetector* me)
{
    RedBlackTree_dispose(me->state);
}

static Vector2D CollisionDetector_voxelHash(const Vector3D position) {
    int xDiv = (int) (position.x / GOOD_VOXEL_SIZE);
    int yDiv = (int) (position.y / GOOD_VOXEL_SIZE);

    double x = GOOD_VOXEL_SIZE * xDiv;
    double y = GOOD_VOXEL_SIZE * yDiv;

    if (position.x < 0) {
        x -= GOOD_VOXEL_SIZE;
    }
    if (position.y < 0) {
        y -= GOOD_VOXEL_SIZE;
    }

    return Vector2D_create(x, y);
}

static bool isInVoxel(const Vector2D voxel, const Motion* motion) {
    if (voxel.x > MAX_X ||
            voxel.x < MIN_X ||
            voxel.y > MAX_Y ||
            voxel.y < MIN_Y) {
        return false;
    }

    Vector3D init = motion->posOne;
    Vector3D fin  = motion->posTwo;

    double v_s = GOOD_VOXEL_SIZE;
    double r   = PROXIMITY_RADIUS / 2.0;

    double v_x = voxel.x;
    double x0 = init.x;
    double xv = fin.x - init.x;

    double v_y = voxel.y;
    double y0 = init.y;
    double yv = fin.y - init.y;

    double low_x;
    double high_x;
    low_x = (v_x - r - x0) / xv;
    high_x = (v_x + v_s + r - x0) / xv;

    if (xv < 0.0) {
        double tmp = low_x;
        low_x = high_x;
        high_x = tmp;
    }

    double low_y;
    double high_y;
    low_y  = (v_y - r - y0) / yv;
    high_y = (v_y + v_s + r - y0) / yv;

    if (yv < 0.0) {
        double tmp = low_y;
        low_y = high_y;
        high_y = tmp;
    }

    return (((xv == 0.0 && v_x <= x0 + r && x0 - r <= v_x + v_s) /* no motion in x */ ||
             (low_x <= 1.0 && 1.0 <= high_x) || (low_x <= 0.0 && 0.0 <= high_x) ||
             (0.0 <= low_x && high_x <= 1.0)) &&
            ((yv == 0.0 && v_y <= y0 + r && y0 - r <= v_y + v_s) /* no motion in y */ ||
             ((low_y <= 1.0 && 1.0 <= high_y) || (low_y <= 0.0 && 0.0 <= high_y) ||
              (0.0 <= low_y && high_y <= 1.0))) &&
            (xv == 0.0 || yv == 0.0 || /* no motion in x or y or both */
             (low_y <= high_x && high_x <= high_y) ||
             (low_y <= low_x && low_x <= high_y) ||
             (low_x <= low_y && high_y <= high_x)));
}

typedef RedBlackTree VoxelMap; // <Vector2D, Vector<Motion>*, Vector2D::Compare>
typedef Vector Motions; // Vector<Motion>

static void putIntoMap( VoxelMap* voxelMap, const Vector2D voxel, const Motion* motion) {
    Motions** array = (Vector**)RedBlackTree_get(voxelMap, &voxel); // Vector<Motion>
    if (array == 0) {
        Motions* a = Vector_createDefault(sizeof(Motion)); // Vector<Motion>
        Vector_append(a, motion);
        RedBlackTree_put(voxelMap, &voxel, &a);
    }else {
        Vector_append(*array, motion);
    }

}

typedef RedBlackTree Seen; // RedBlackTree<Vector2D, bool, Vector2D::Compare>

static void recurse( VoxelMap* voxelMap, Seen* seen, const Vector2D nextVoxel, const Motion* motion)
{
    if (!isInVoxel(nextVoxel, motion)) {
        return;
    }

    const bool t = true;
    bool* res = (bool*)RedBlackTree_put(seen, &nextVoxel, &t);
    if ( res && *res) {
        return;
    }

    putIntoMap(voxelMap, nextVoxel, motion);

    recurse(voxelMap, seen, Vector2D_minus(nextVoxel, horizontal), motion);
    recurse(voxelMap, seen, Vector2D_plus(nextVoxel, horizontal), motion);
    recurse(voxelMap, seen, Vector2D_minus(nextVoxel, vertical), motion);
    recurse(voxelMap, seen, Vector2D_plus(nextVoxel, vertical), motion);
    recurse(voxelMap, seen, Vector2D_minus(Vector2D_minus(nextVoxel, horizontal),vertical), motion);
    recurse(voxelMap, seen, Vector2D_plus(Vector2D_minus(nextVoxel, horizontal),vertical), motion);
    recurse(voxelMap, seen, Vector2D_minus(Vector2D_plus(nextVoxel, horizontal),vertical), motion);
    recurse(voxelMap, seen, Vector2D_plus(Vector2D_plus(nextVoxel, horizontal),vertical), motion);
}

typedef Vector ReductionResult; // Vector<Vector<Motion>>

static void drawMotionOnVoxelMap(VoxelMap* voxelMap, const Motion* motion) {
    Seen* seen = RedBlackTree_create(sizeof(Vector2D),sizeof(bool),Vector2D_compare);
    // <Vector2D, bool, Vector2D::Compare>
    recurse(voxelMap, seen, CollisionDetector_voxelHash(motion->posOne), motion);
    RedBlackTree_dispose(seen);
}

static void reduceCollisionSet_iter2(const Bytes key, const Bytes value, void* data)
{
    ReductionResult* result = data;
    // <Vector2D, Motions*, Vector2D::Compare>
    Motions* motions = *(Motions**)value;
    if (Vector_size(motions) > 1) {
        Vector_append(result, &motions);
    }else
        Vector_dispose(motions);
}

void reduceCollisionSet_iter1(const Bytes value, void* data)
{
    VoxelMap* voxelMap = data;
    const Motion* motion = value;

    drawMotionOnVoxelMap(voxelMap, motion);
}

static void reduceCollisionSet(Motions* motions, ReductionResult* result) {
    VoxelMap* voxelMap = RedBlackTree_create(sizeof(Vector2D),sizeof(Motions*),Vector2D_compare);
    // <Vector2D, Motions*, Vector2D::Compare>

    for( int i = 0; i < Vector_size(result); i++ )
    {
        Vector* m = *(Vector**)Vector_at(result,i);
        Vector_removeAll(m);
    }
    Vector_removeAll(result);

#ifdef USE_FANCY_ITERATORS

    Vector_forEach(motions,reduceCollisionSet_iter1,voxelMap);

#else
    for( int i = 0; i < Vector_size(motions); i++ )
    {
        Motion* motion = (Motion*)Vector_at(motions,i);
        drawMotionOnVoxelMap(voxelMap, motion);
    }
#endif

    RedBlackTree_forEach(voxelMap, reduceCollisionSet_iter2, result);
    RedBlackTree_dispose(voxelMap);
}

typedef Vector Frame;  // Vector<Aircraft>
typedef Vector Collisions; // Vector<Collision>
typedef RedBlackTree Seen2; // RedBlackTree<CallSign, bool, CallSign::Compare>

struct CollisionDetector_handleNewFrame_Iter2 {
    Seen2* seen;
    Vector* toRemove;   // Vector<CallSign>
};

static void CollisionDetector_handleNewFrame_iter2(const Bytes key, const Bytes value, void* data)
{
    struct CollisionDetector_handleNewFrame_Iter2* cl = data;
    if (!RedBlackTree_get(cl->seen, key)) {
        Vector_append(cl->toRemove, key);
    }
}

struct CollisionDetector_handleNewFrame_Iter1 {
    Seen2* seen;
    RedBlackTree* state;
    Motions* motions;
};

void CollisionDetector_handleNewFrame_iter1(const Bytes value, void* data)
{
    const Aircraft* aircraft = value;
    struct CollisionDetector_handleNewFrame_Iter1* me = data;

    Vector3D* oldPosition = RedBlackTree_put(me->state, &aircraft->callsign, &aircraft->position);
    Vector3D newPosition = aircraft->position;
    const bool t = true;
    RedBlackTree_put(me->seen, &aircraft->callsign, &t);

    if (oldPosition == 0) {
        // Treat newly introduced aircraft as if they were stationary.
        Motion tmp = Motion_create(aircraft->callsign, newPosition, newPosition);
        Vector_append(me->motions, &tmp);
    }else
    {
        Motion tmp = Motion_create(aircraft->callsign, *oldPosition, newPosition);
        Vector_append(me->motions, &tmp);
    }
}

void CollisionDetector_handleNewFrame_iter3(const Bytes value, void* data)
{
    const CallSign* e = value;
    RedBlackTree* state = data;
    RedBlackTree_remove(state, e);
}

void CollisionDetector_handleNewFrame_iter4(const Bytes value, void* data)
{
    const Vector** reduced = value;
    Collisions* collisions = data;

    for (int i = 0; i < Vector_size(*reduced); ++i) {
        const Motion* motion1 = Vector_at(*reduced, i);
        for (int j = i + 1; j < Vector_size(*reduced); ++j) {
            const Motion* motion2 = Vector_at(*reduced, j);
            Vector3D collision = { 0 };
            const bool hit = Motion_findIntersection(motion1, motion2, &collision);
            if( hit ) {
                Collision tmp = Collision_create(motion1->callsign, motion2->callsign, collision);
                Vector_append(collisions, &tmp);
            }
        }
    }
}

static void CollisionDetector_handleNewFrame(CollisionDetector* me, Frame* frame, Collisions* collisions) {
    Motions* motions = Vector_createDefault(sizeof(Motion));
    Seen2* seen = RedBlackTree_create(sizeof(CallSign),sizeof(bool), CallSign_compare);

#ifdef USE_FANCY_ITERATORS
    struct CollisionDetector_handleNewFrame_Iter1 iter1;
    iter1.seen = seen;
    iter1.motions = motions;
    iter1.state = me->state;

    Vector_forEach(frame, CollisionDetector_handleNewFrame_iter1,&iter1);
#else
    for( int i = 0; i < Vector_size(frame); i++ )
    {
        const Aircraft* aircraft = (Aircraft*)Vector_at(frame, i);
        Vector3D* oldPosition = (Vector3D*)RedBlackTree_put(me->state, &aircraft->callsign, &aircraft->position);
                    // RedBlackTree<CallSign, Vector3D, CallSign::Compare>

        Vector3D newPosition = aircraft->position;
        const bool t = true;
        RedBlackTree_put(seen, &aircraft->callsign, &t);

        if (oldPosition == 0) {
            // Treat newly introduced aircraft as if they were stationary.
            Motion tmp = Motion_create(aircraft->callsign, newPosition, newPosition);
            Vector_append(motions, &tmp);
        }else {
            Motion tmp = Motion_create(aircraft->callsign, *oldPosition, newPosition);           
            Vector_append(motions, &tmp);
        }
    }
#endif

    // Remove aircraft that are no longer present.
    Vector* toRemove = Vector_createDefault(sizeof(CallSign)); // Vector<CallSign>

    struct CollisionDetector_handleNewFrame_Iter2 c;
    c.seen = seen;
    c.toRemove = toRemove;

    RedBlackTree_forEach(me->state, CollisionDetector_handleNewFrame_iter2, &c);

#ifdef USE_FANCY_ITERATORS

    Vector_forEach(toRemove, CollisionDetector_handleNewFrame_iter3,me->state);

#else
    for( int i = 0; i < Vector_size(toRemove); i++ )
    {
        const CallSign* e = (CallSign*)Vector_at(toRemove, i);
        RedBlackTree_remove(me->state, e);
    }
#endif

    // bis hier ist motions identisch mit c++ version
    ReductionResult* allReduced = Vector_createDefault(sizeof(Vector*));
    reduceCollisionSet(motions, allReduced);

    Vector_removeAll(collisions);

#ifdef USE_FANCY_ITERATORS

    Vector_forEach(allReduced, CollisionDetector_handleNewFrame_iter4, collisions);

#else
    for( int k = 0; k < Vector_size(allReduced); k++ )
    {
        const Motions* reduced = *(Motions**)Vector_at(allReduced, k);
        for (int i = 0; i < Vector_size(reduced); ++i) {
            Motion* motion1 = (Motion*)Vector_at(reduced, i);
            for (int j = i + 1; j < Vector_size(reduced); ++j) {
                Motion* motion2 = (Motion*)Vector_at(reduced, j);
                Vector3D collision = Vector3D_create(0,0,0);
                const bool hit = Motion_findIntersection(motion1, motion2, &collision);
                if( hit ) {
                    Collision tmp = Collision_create(motion1->callsign, motion2->callsign, collision);
                    Vector_append(collisions, &tmp);
                }
            }
        }
    }
#endif

    RedBlackTree_dispose(seen);
    Vector_dispose(motions);
    for(int i = 0; i < Vector_size(allReduced); i++ ) {
        Vector* v = *(Vector**)Vector_at(allReduced,i);
        Vector_dispose(v);
    }
    Vector_dispose(allReduced);
    Vector_dispose(toRemove);
}

typedef struct Simulator {
    Vector* aircraft; // Vector<CallSign>
} Simulator;

static void Simulator_init(Simulator* me, int numAircraft) {
    me->aircraft = Vector_createDefault(sizeof(CallSign));
    for (int i = 0; i < numAircraft; i++) {
        CallSign tmp = CallSign_create(i);
        Vector_append(me->aircraft, &tmp);
    }
}

static void Simulator_deinit(Simulator* me) {
    Vector_dispose(me->aircraft);
}

static void simulate(Simulator* me, Frame* frame, double time) {
    for (int i = 0; i < Vector_size(me->aircraft); i += 2) {
        Aircraft tmp = Aircraft_create((CallSign*)Vector_at(me->aircraft, i),
                                       Vector3D_create(time, cos(time) * 2 + i * 3, 10));
        Vector_append(frame,&tmp);
        tmp = Aircraft_create((CallSign*)Vector_at(me->aircraft,i + 1),
                        Vector3D_create(time, sin(time) * 2 + i * 3, 10));
        Vector_append(frame,&tmp);
    }
}

static int benchmark2(int numAircrafts)
{

    int numFrames = 200;

    Simulator simulator;
    Simulator_init(&simulator,numAircrafts);
    CollisionDetector detector;
    CollisionDetector_init(&detector);

    int actualCollisions = 0;

    for (int i = 0; i < numFrames; i++) {
        double time = i / 10.0;
        Frame* frame = Vector_createDefault(sizeof(Aircraft));
        simulate(&simulator, frame, time);
        Collisions* collisions = Vector_createDefault(sizeof(Collision));
        CollisionDetector_handleNewFrame(&detector, frame, collisions);
        const int sz = Vector_size(collisions);
        actualCollisions += sz;
        Vector_dispose(frame);
        Vector_dispose(collisions);
    }

    CollisionDetector_deinit(&detector);
    Simulator_deinit(&simulator);

    return actualCollisions;
}

static bool verifyResult2(int actualCollisions, int numAircrafts)
{
    if (numAircrafts == 1000) { return actualCollisions == 14484; }
    if (numAircrafts ==  500) { return actualCollisions == 14484; }
    if (numAircrafts ==  250) { return actualCollisions == 10830; }
    if (numAircrafts ==  200) { return actualCollisions ==  8655; }
    if (numAircrafts ==  100) { return actualCollisions ==  4305; }
    if (numAircrafts ==   10) { return actualCollisions ==   390; }
    if (numAircrafts ==    2) { return actualCollisions ==    42; }

    // Checkstyle: stop
    fprintf(stderr, "No verification result for %d found\n", numAircrafts);
    fprintf(stderr, "Result is: %d\n", actualCollisions);
    // Checkstyle: resume
    return false;
}

static bool innerBenchmarkLoop(Benchmark* me, int innerIterations) {
    return verifyResult2(benchmark2(innerIterations), innerIterations);
}

static int benchmark(Benchmark* me) {
    assert(0); // "Should never be reached"
}

static bool verifyResult(Benchmark* me,int result) {
    assert(0); // "Should never be reached"
}

Benchmark* CD_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = innerBenchmarkLoop;
    return bench;
}
