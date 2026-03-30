(* Copyright (c) 2001-2016 Stefan Marr
 * Copyright (c) 2026 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
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
 *)

MODULE CD;

IMPORT SOM, Benchmark, RedBlackTree, MathL;

CONST
  MinX = 0.0D0; MinY = 0.0D0;
  MaxX = 1000.0D0; MaxY = 1000.0D0;
  MinZ = 0.0D0; MaxZ = 10.0D0;
  ProximityRadius = 1.0D0;
  GoodVoxelSize = 2.0D0;

TYPE
  INT32 = SOM.INT32;
  F64 = SOM.F64;

  CD* = POINTER TO CDDesc;
  CDDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  Vector2D = POINTER TO Vector2DDesc;
  Vector2DDesc = RECORD (SOM.ObjectDesc)
    x, y: F64;
  END;

  Vector3D = POINTER TO Vector3DDesc;
  Vector3DDesc = RECORD (SOM.ObjectDesc)
    x, y, z: F64;
  END;

  CallSign = POINTER TO CallSignDesc;
  CallSignDesc = RECORD (SOM.ObjectDesc)
    value: INT32;
  END;

  Aircraft = POINTER TO AircraftDesc;
  AircraftDesc = RECORD (SOM.ObjectDesc)
    callsign: CallSign;
    position: Vector3D;
  END;

  Collision = POINTER TO CollisionDesc;
  CollisionDesc = RECORD (SOM.ObjectDesc)
    aircraftA, aircraftB: CallSign;
    position: Vector3D;
  END;

  Motion = POINTER TO MotionDesc;
  MotionDesc = RECORD (SOM.ObjectDesc)
    callsign: CallSign;
    posOne, posTwo: Vector3D;
  END;

  CollisionDetector = POINTER TO CollisionDetectorDesc;
  CollisionDetectorDesc = RECORD (SOM.ObjectDesc)
    state: RedBlackTree.Tree;
  END;

  Simulator = POINTER TO SimulatorDesc;
  SimulatorDesc = RECORD (SOM.ObjectDesc)
    aircraft: SOM.Vector;
  END;

  ReduceIterData = POINTER TO ReduceIterDataDesc;
  ReduceIterDataDesc = RECORD (SOM.ObjectDesc)
    result: SOM.Vector;
  END;

  HandleFrameIterData = POINTER TO HandleFrameIterDataDesc;
  HandleFrameIterDataDesc = RECORD (SOM.ObjectDesc)
    seen: RedBlackTree.Tree;
    toRemove: SOM.Vector;
    state: RedBlackTree.Tree;
    motions: SOM.Vector;
  END;

(* --- Vector2D --- *)

PROCEDURE CreateVector2D(x, y: F64): Vector2D;
  VAR v: Vector2D;
BEGIN
  NEW(v); v.x := x; v.y := y; RETURN v
END CreateVector2D;

PROCEDURE Vector2DPlus(a, b: Vector2D): Vector2D;
BEGIN
  RETURN CreateVector2D(a.x + b.x, a.y + b.y)
END Vector2DPlus;

PROCEDURE Vector2DMinus(a, b: Vector2D): Vector2D;
BEGIN
  RETURN CreateVector2D(a.x - b.x, a.y - b.y)
END Vector2DMinus;

PROCEDURE CompareNumbers(a, b: F64): INTEGER;
BEGIN
  IF a = b THEN RETURN 0 END;
  IF a < b THEN RETURN -1 END;
  IF a > b THEN RETURN 1 END;
  IF a = a THEN RETURN 1 END;
  RETURN -1
END CompareNumbers;

PROCEDURE Vector2DCompare(l, r: SOM.Object): INTEGER;
  VAR lhs, rhs: Vector2D; result: INTEGER;
BEGIN
  lhs := l(Vector2D); rhs := r(Vector2D);
  result := CompareNumbers(lhs.x, rhs.x);
  IF result # 0 THEN RETURN result END;
  RETURN CompareNumbers(lhs.y, rhs.y)
END Vector2DCompare;

(* --- Vector3D --- *)

PROCEDURE CreateVector3D(x, y, z: F64): Vector3D;
  VAR v: Vector3D;
BEGIN
  NEW(v); v.x := x; v.y := y; v.z := z; RETURN v
END CreateVector3D;

PROCEDURE Vector3DPlus(a, b: Vector3D): Vector3D;
BEGIN
  RETURN CreateVector3D(a.x + b.x, a.y + b.y, a.z + b.z)
END Vector3DPlus;

PROCEDURE Vector3DMinus(a, b: Vector3D): Vector3D;
BEGIN
  RETURN CreateVector3D(a.x - b.x, a.y - b.y, a.z - b.z)
END Vector3DMinus;

PROCEDURE Vector3DDot(a, b: Vector3D): F64;
BEGIN
  RETURN a.x * b.x + a.y * b.y + a.z * b.z
END Vector3DDot;

PROCEDURE Vector3DSquaredMagnitude(v: Vector3D): F64;
BEGIN
  RETURN Vector3DDot(v, v)
END Vector3DSquaredMagnitude;

PROCEDURE Vector3DMagnitude(v: Vector3D): F64;
BEGIN
  RETURN MathL.sqrt(Vector3DSquaredMagnitude(v))
END Vector3DMagnitude;

PROCEDURE Vector3DTimes(v: Vector3D; amount: F64): Vector3D;
BEGIN
  RETURN CreateVector3D(v.x * amount, v.y * amount, v.z * amount)
END Vector3DTimes;

(* --- CallSign --- *)

PROCEDURE CreateCallSign(value: INT32): CallSign;
  VAR c: CallSign;
BEGIN
  NEW(c); c.value := value; RETURN c
END CreateCallSign;

PROCEDURE CallSignCompare(l, r: SOM.Object): INTEGER;
  VAR lhs, rhs: CallSign;
BEGIN
  lhs := l(CallSign); rhs := r(CallSign);
  IF lhs.value = rhs.value THEN RETURN 0
  ELSIF lhs.value < rhs.value THEN RETURN -1
  ELSE RETURN 1
  END
END CallSignCompare;

(* --- Aircraft --- *)

PROCEDURE CreateAircraft(cs: CallSign; pos: Vector3D): Aircraft;
  VAR a: Aircraft;
BEGIN
  NEW(a); a.callsign := cs; a.position := pos; RETURN a
END CreateAircraft;

(* --- Collision --- *)

PROCEDURE CreateCollision(a, b: CallSign; pos: Vector3D): Collision;
  VAR c: Collision;
BEGIN
  NEW(c); c.aircraftA := a; c.aircraftB := b; c.position := pos; RETURN c
END CreateCollision;

(* --- Motion --- *)

PROCEDURE CreateMotion(cs: CallSign; p1, p2: Vector3D): Motion;
  VAR m: Motion;
BEGIN
  NEW(m); m.callsign := cs; m.posOne := p1; m.posTwo := p2; RETURN m
END CreateMotion;

PROCEDURE MotionDelta(m: Motion): Vector3D;
BEGIN
  RETURN Vector3DMinus(m.posTwo, m.posOne)
END MotionDelta;

PROCEDURE MotionFindIntersection(me, other: Motion; VAR result: Vector3D): BOOLEAN;
  VAR init1, init2, vec1, vec2: Vector3D;
      a, b, c, discr, v1, v2, v: F64;
      result1, result2, res: Vector3D;
BEGIN
  init1 := me.posOne; init2 := other.posOne;
  vec1 := MotionDelta(me); vec2 := MotionDelta(other);

  a := Vector3DSquaredMagnitude(Vector3DMinus(vec2, vec1));

  IF a # 0.0D0 THEN
    b := 2.0D0 * Vector3DDot(Vector3DMinus(init1, init2), Vector3DMinus(vec1, vec2));
    c := -ProximityRadius * ProximityRadius + Vector3DSquaredMagnitude(Vector3DMinus(init2, init1));
    discr := b * b - 4.0D0 * a * c;
    IF discr < 0.0D0 THEN RETURN FALSE END;

    v1 := (-b - MathL.sqrt(discr)) / (2.0D0 * a);
    v2 := (-b + MathL.sqrt(discr)) / (2.0D0 * a);

    IF (v1 <= v2) & (((v1 <= 1.0D0) & (1.0D0 <= v2)) OR
                      ((v1 <= 0.0D0) & (0.0D0 <= v2)) OR
                      ((0.0D0 <= v1) & (v2 <= 1.0D0))) THEN
      IF v1 <= 0.0D0 THEN v := 0.0D0 ELSE v := v1 END;
      result1 := Vector3DPlus(init1, Vector3DTimes(vec1, v));
      result2 := Vector3DPlus(init2, Vector3DTimes(vec2, v));
      res := Vector3DTimes(Vector3DPlus(result1, result2), 0.5D0);
      IF (res.x >= MinX) & (res.x <= MaxX) & (res.y >= MinY) & (res.y <= MaxY) &
         (res.z >= MinZ) & (res.z <= MaxZ) THEN
        result := res;
        RETURN TRUE
      END;
    END;
    RETURN FALSE
  END;

  IF Vector3DMagnitude(Vector3DMinus(init2, init1)) <= ProximityRadius THEN
    result := Vector3DTimes(Vector3DPlus(init1, init2), 0.5D0);
    RETURN TRUE
  END;
  RETURN FALSE
END MotionFindIntersection;

(* --- Voxel Hashing --- *)

PROCEDURE VoxelHash(position: Vector3D): Vector2D;
  VAR xDiv, yDiv: INT32; x, y: F64;
BEGIN
  xDiv := ENTIER(position.x / GoodVoxelSize);
  yDiv := ENTIER(position.y / GoodVoxelSize);
  x := GoodVoxelSize * xDiv;
  y := GoodVoxelSize * yDiv;
  IF position.x < 0.0D0 THEN x := x - GoodVoxelSize END;
  IF position.y < 0.0D0 THEN y := y - GoodVoxelSize END;
  RETURN CreateVector2D(x, y)
END VoxelHash;

PROCEDURE IsInVoxel(voxel: Vector2D; motion: Motion): BOOLEAN;
  VAR init, fin: Vector3D;
      vS, r, vX, x0, xv, vY, y0, yv, lowX, highX, lowY, highY, tmp: F64;
      xOk, yOk, xyOk: BOOLEAN;
BEGIN
  IF (voxel.x > MaxX) OR (voxel.x < MinX) OR (voxel.y > MaxY) OR (voxel.y < MinY) THEN
    RETURN FALSE
  END;
  init := motion.posOne; fin := motion.posTwo;
  vS := GoodVoxelSize; r := ProximityRadius / 2.0D0;
  vX := voxel.x; x0 := init.x; xv := fin.x - init.x;
  vY := voxel.y; y0 := init.y; yv := fin.y - init.y;

  lowX := (vX - r - x0) / xv; highX := (vX + vS + r - x0) / xv;
  IF xv < 0.0D0 THEN tmp := lowX; lowX := highX; highX := tmp END;

  lowY := (vY - r - y0) / yv; highY := (vY + vS + r - y0) / yv;
  IF yv < 0.0D0 THEN tmp := lowY; lowY := highY; highY := tmp END;

  xOk := ((xv = 0.0D0) & (vX <= x0 + r) & (x0 - r <= vX + vS)) OR
         ((lowX <= 1.0D0) & (1.0D0 <= highX)) OR
         ((lowX <= 0.0D0) & (0.0D0 <= highX)) OR
         ((0.0D0 <= lowX) & (highX <= 1.0D0));

  yOk := ((yv = 0.0D0) & (vY <= y0 + r) & (y0 - r <= vY + vS)) OR
         ((lowY <= 1.0D0) & (1.0D0 <= highY)) OR
         ((lowY <= 0.0D0) & (0.0D0 <= highY)) OR
         ((0.0D0 <= lowY) & (highY <= 1.0D0));

  xyOk := (xv = 0.0D0) OR (yv = 0.0D0) OR
          ((lowY <= highX) & (highX <= highY)) OR
          ((lowY <= lowX) & (lowX <= highY)) OR
          ((lowX <= lowY) & (highY <= highX));

  RETURN xOk & yOk & xyOk
END IsInVoxel;

(* --- VoxelMap operations --- *)

PROCEDURE PutIntoMap(voxelMap: RedBlackTree.Tree; voxel: Vector2D; motion: Motion);
  VAR existing: SOM.Object; motions: SOM.Vector;
BEGIN
  existing := RedBlackTree.Get(voxelMap, voxel);
  IF existing = NIL THEN
    motions := SOM.CreateVector(0);
    SOM.VectorAppend(motions, motion);
    existing := RedBlackTree.Put(voxelMap, voxel, motions);
  ELSE
    SOM.VectorAppend(existing(SOM.Vector), motion);
  END;
END PutIntoMap;

PROCEDURE Recurse(voxelMap, seen: RedBlackTree.Tree; nextVoxel: Vector2D; motion: Motion);
  VAR res: SOM.Object; horizontal, vertical: Vector2D;
BEGIN
  IF ~IsInVoxel(nextVoxel, motion) THEN RETURN END;
  res := RedBlackTree.Put(seen, nextVoxel, SOM.CreateBoolObject(TRUE));
  IF (res # NIL) & (res IS SOM.BoolObject) & res(SOM.BoolObject).value THEN RETURN END;
  PutIntoMap(voxelMap, nextVoxel, motion);
  horizontal := CreateVector2D(GoodVoxelSize, 0.0D0);
  vertical := CreateVector2D(0.0D0, GoodVoxelSize);
  Recurse(voxelMap, seen, Vector2DMinus(nextVoxel, horizontal), motion);
  Recurse(voxelMap, seen, Vector2DPlus(nextVoxel, horizontal), motion);
  Recurse(voxelMap, seen, Vector2DMinus(nextVoxel, vertical), motion);
  Recurse(voxelMap, seen, Vector2DPlus(nextVoxel, vertical), motion);
  Recurse(voxelMap, seen, Vector2DMinus(Vector2DMinus(nextVoxel, horizontal), vertical), motion);
  Recurse(voxelMap, seen, Vector2DPlus(Vector2DMinus(nextVoxel, horizontal), vertical), motion);
  Recurse(voxelMap, seen, Vector2DMinus(Vector2DPlus(nextVoxel, horizontal), vertical), motion);
  Recurse(voxelMap, seen, Vector2DPlus(Vector2DPlus(nextVoxel, horizontal), vertical), motion);
END Recurse;

PROCEDURE DrawMotionOnVoxelMap(voxelMap: RedBlackTree.Tree; motion: Motion);
  VAR seen: RedBlackTree.Tree;
BEGIN
  seen := RedBlackTree.Create(Vector2DCompare);
  Recurse(voxelMap, seen, VoxelHash(motion.posOne), motion);
END DrawMotionOnVoxelMap;

PROCEDURE ReduceCollisionSetIter(key, value: SOM.Object; data: SOM.Object);
  VAR result: SOM.Vector; motions: SOM.Vector;
BEGIN
  result := data(ReduceIterData).result;
  motions := value(SOM.Vector);
  IF SOM.VectorSize(motions) > 1 THEN
    SOM.VectorAppend(result, motions);
  END;
END ReduceCollisionSetIter;

PROCEDURE ReduceCollisionSet(motions: SOM.Vector; result: SOM.Vector);
  VAR voxelMap: RedBlackTree.Tree; i: INT32; motion: Motion;
      iterData: ReduceIterData;
BEGIN
  voxelMap := RedBlackTree.Create(Vector2DCompare);
  SOM.VectorRemoveAll(result);
  FOR i := 0 TO SOM.VectorSize(motions) - 1 DO
    motion := SOM.VectorAt(motions, i)(Motion);
    DrawMotionOnVoxelMap(voxelMap, motion);
  END;
  NEW(iterData); iterData.result := result;
  RedBlackTree.ForEach(voxelMap, ReduceCollisionSetIter, iterData);
END ReduceCollisionSet;

(* --- CollisionDetector --- *)

PROCEDURE CreateCollisionDetector(): CollisionDetector;
  VAR cd: CollisionDetector;
BEGIN
  NEW(cd);
  cd.state := RedBlackTree.Create(CallSignCompare);
  RETURN cd
END CreateCollisionDetector;

PROCEDURE HandleNewFrameRemoveIter(key, value: SOM.Object; data: SOM.Object);
  VAR d: HandleFrameIterData;
BEGIN
  d := data(HandleFrameIterData);
  IF RedBlackTree.Get(d.seen, key) = NIL THEN
    SOM.VectorAppend(d.toRemove, key);
  END;
END HandleNewFrameRemoveIter;

PROCEDURE HandleNewFrame(cd: CollisionDetector; frame, collisions: SOM.Vector);
  VAR motions: SOM.Vector; seen: RedBlackTree.Tree;
      i, j, k: INT32;
      ac: Aircraft; oldPosition, newPosition: Vector3D;
      toRemove: SOM.Vector;
      iterData: HandleFrameIterData;
      allReduced, reduced: SOM.Vector;
      motion1, motion2: Motion; coll: Vector3D;
      hit: BOOLEAN; cs: CallSign;
BEGIN
  motions := SOM.CreateVector(0);
  seen := RedBlackTree.Create(CallSignCompare);

  FOR i := 0 TO SOM.VectorSize(frame) - 1 DO
    ac := SOM.VectorAt(frame, i)(Aircraft);
    oldPosition := RedBlackTree.Put(cd.state, ac.callsign, ac.position)(Vector3D);
    newPosition := ac.position;
    RedBlackTree.Put(seen, ac.callsign, SOM.CreateBoolObject(TRUE));
    IF oldPosition = NIL THEN
      SOM.VectorAppend(motions, CreateMotion(ac.callsign, newPosition, newPosition));
    ELSE
      SOM.VectorAppend(motions, CreateMotion(ac.callsign, oldPosition, newPosition));
    END;
  END;

  toRemove := SOM.CreateVector(0);
  NEW(iterData);
  iterData.seen := seen; iterData.toRemove := toRemove;
  RedBlackTree.ForEach(cd.state, HandleNewFrameRemoveIter, iterData);

  FOR i := 0 TO SOM.VectorSize(toRemove) - 1 DO
    cs := SOM.VectorAt(toRemove, i)(CallSign);
    RedBlackTree.Remove(cd.state, cs);
  END;

  allReduced := SOM.CreateVector(0);
  ReduceCollisionSet(motions, allReduced);

  SOM.VectorRemoveAll(collisions);
  FOR k := 0 TO SOM.VectorSize(allReduced) - 1 DO
    reduced := SOM.VectorAt(allReduced, k)(SOM.Vector);
    FOR i := 0 TO SOM.VectorSize(reduced) - 1 DO
      motion1 := SOM.VectorAt(reduced, i)(Motion);
      FOR j := i + 1 TO SOM.VectorSize(reduced) - 1 DO
        motion2 := SOM.VectorAt(reduced, j)(Motion);
        coll := CreateVector3D(0.0D0, 0.0D0, 0.0D0);
        hit := MotionFindIntersection(motion1, motion2, coll);
        IF hit THEN
          SOM.VectorAppend(collisions, CreateCollision(motion1.callsign, motion2.callsign, coll));
        END;
      END;
    END;
  END;
END HandleNewFrame;

(* --- Simulator --- *)

PROCEDURE CreateSimulator(numAircraft: INT32): Simulator;
  VAR s: Simulator; i: INT32;
BEGIN
  NEW(s);
  s.aircraft := SOM.CreateVector(0);
  FOR i := 0 TO numAircraft - 1 DO
    SOM.VectorAppend(s.aircraft, CreateCallSign(i));
  END;
  RETURN s
END CreateSimulator;

PROCEDURE Simulate(sim: Simulator; frame: SOM.Vector; time: F64);
  VAR i: INT32; cs: CallSign;
BEGIN
  i := 0;
  WHILE i + 1 < SOM.VectorSize(sim.aircraft) DO
    cs := SOM.VectorAt(sim.aircraft, i)(CallSign);
    ASSERT(cs # NIL);
    SOM.VectorAppend(frame, CreateAircraft(cs,
      CreateVector3D(time, MathL.cos(time) * 2.0D0 + i * 3.0D0, 10.0D0)));
    cs := SOM.VectorAt(sim.aircraft, i + 1)(CallSign);
    ASSERT(cs # NIL);
    SOM.VectorAppend(frame, CreateAircraft(cs,
      CreateVector3D(time, MathL.sin(time) * 2.0D0 + i * 3.0D0, 10.0D0)));
    INC(i, 2);
  END;
END Simulate;

(* --- Benchmark2 --- *)

PROCEDURE Benchmark2(numAircrafts: INT32): INT32;
  VAR numFrames, i, actualCollisions: INT32;
      simulator: Simulator;
      detector: CollisionDetector;
      time: F64;
      frame, collisions: SOM.Vector;
BEGIN
  numFrames := 200;
  simulator := CreateSimulator(numAircrafts);
  detector := CreateCollisionDetector();
  actualCollisions := 0;
  FOR i := 0 TO numFrames - 1 DO
    time := i / 10.0D0;
    frame := SOM.CreateVector(0);
    Simulate(simulator, frame, time);
    collisions := SOM.CreateVector(0);
    HandleNewFrame(detector, frame, collisions);
    actualCollisions := actualCollisions + SOM.VectorSize(collisions);
  END;
  RETURN actualCollisions
END Benchmark2;

PROCEDURE VerifyResult2(actualCollisions, numAircrafts: INT32): BOOLEAN;
BEGIN
  IF numAircrafts = 1000 THEN RETURN actualCollisions = 14484 END;
  IF numAircrafts =  500 THEN RETURN actualCollisions = 14484 END;
  IF numAircrafts =  250 THEN RETURN actualCollisions = 10830 END;
  IF numAircrafts =  200 THEN RETURN actualCollisions =  8655 END;
  IF numAircrafts =  100 THEN RETURN actualCollisions =  4305 END;
  IF numAircrafts =   10 THEN RETURN actualCollisions =   390 END;
  IF numAircrafts =    2 THEN
    RETURN (actualCollisions = 42)
  END;
  RETURN FALSE
END VerifyResult2;

(* --- Benchmark Interface --- *)

PROCEDURE InnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
BEGIN
  RETURN VerifyResult2(Benchmark2(innerIterations), innerIterations)
END InnerBenchmarkLoop;

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
BEGIN
  HALT(99);
  RETURN NIL
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  HALT(99);
  RETURN FALSE
END VerifyResult;

PROCEDURE Create*(): CD;
  VAR cd: CD;
BEGIN
  NEW(cd);
  cd.InnerBenchmarkLoop := InnerBenchmarkLoop;
  cd.DoBenchmark := DoBenchmark;
  cd.VerifyResult := VerifyResult;
  RETURN cd
END Create;

END CD.
