(* The Computer Language Benchmarks Game
 * http://shootout.alioth.debian.org/
 *
 * Based on nbody.java and adapted based on the SOM version.
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
 *)

MODULE NBody;

(*
  This module implements the NBody benchmark. It simulates the gravitational
  interactions between several planetary bodies over a period of time. It is
  a compute-intensive benchmark focusing on floating-point arithmetic.
*)

IMPORT Benchmark, SOM, MathL, Out;

CONST
  PI = 3.141592653589793;
  SOLARMASS = 4.0 * PI * PI;
  DAYSPERYEAR = 365.24;
  Count = 5;

TYPE
  REAL64 = SOM.F64;
  INT32  = SOM.INT32;

  Body = POINTER TO BodyDesc;
  BodyDesc = RECORD(SOM.ObjectDesc)
    x, y, z, vx, vy, vz, mass: REAL64;
  END;

  NBodySystem = POINTER TO NBodySystemDesc;
  NBodySystemDesc = RECORD(SOM.ObjectDesc)
    bodies: POINTER TO ARRAY OF Body;
  END;

  NBody* = POINTER TO NBodyDesc;
  NBodyDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

PROCEDURE NewBody(x, y, z, vx, vy, vz, mass: REAL64): Body;
  VAR b: Body;
BEGIN
  NEW(b);
  b.x := x;
  b.y := y;
  b.z := z;
  b.vx := vx * DAYSPERYEAR;
  b.vy := vy * DAYSPERYEAR;
  b.vz := vz * DAYSPERYEAR;
  b.mass := mass * SOLARMASS;
  RETURN b
END NewBody;

PROCEDURE Jupiter(): Body;
BEGIN
  RETURN NewBody(
    4.84143144246472090,
    -1.16032004402742839,
    -1.03622044471123109E-1,
    1.66007664274403694E-3,
    7.69901118419740425E-3,
    -6.90460016972063023E-5,
    9.54791938424326609E-4)
END Jupiter;

PROCEDURE Saturn(): Body;
BEGIN
  RETURN NewBody(
    8.34336671824457987,
    4.12479856412430479,
    -4.03523417114321381E-1,
    -2.76742510726862411E-3,
    4.99852801234917238E-3,
    2.30417297573763929E-5,
    2.85885980666130812E-4)
END Saturn;

PROCEDURE Uranus(): Body;
BEGIN
  RETURN NewBody(
    1.28943695621391310E+1,
    -1.51111514016986312E+1,
    -2.23307578892655734E-1,
    2.96460137564761618E-3,
    2.37847173959480950E-3,
    -2.96589568540237556E-5,
    4.36624404335156298E-5)
END Uranus;

PROCEDURE Neptune(): Body;
BEGIN
  RETURN NewBody(
    1.53796971148509165E+1,
    -2.59193146099879641E+1,
    1.79258772950371181E-1,
    2.68067772490389322E-3,
    1.62824170038242295E-3,
    -9.51592254519715870E-5,
    5.15138902046611451E-5)
END Neptune;

PROCEDURE Sun(): Body;
BEGIN
  RETURN NewBody(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0)
END Sun;

PROCEDURE OffsetMomentum(b: Body; px, py, pz: REAL64);
BEGIN
  b.vx := 0.0 - (px / SOLARMASS);
  b.vy := 0.0 - (py / SOLARMASS);
  b.vz := 0.0 - (pz / SOLARMASS);
END OffsetMomentum;

PROCEDURE CreateNBodySystem(): NBodySystem;
  VAR sys: NBodySystem; px, py, pz: REAL64; i: INT32; b: Body;
BEGIN
  NEW(sys);
  NEW(sys.bodies, Count);
  sys.bodies[0] := Sun();
  sys.bodies[1] := Jupiter();
  sys.bodies[2] := Saturn();
  sys.bodies[3] := Uranus();
  sys.bodies[4] := Neptune();

  px := 0.0; py := 0.0; pz := 0.0;
  FOR i := 0 TO Count - 1 DO
    b := sys.bodies[i];
    px := px + b.vx * b.mass;
    py := py + b.vy * b.mass;
    pz := pz + b.vz * b.mass;
  END;
  OffsetMomentum(sys.bodies[0], px, py, pz);
  RETURN sys
END CreateNBodySystem;

PROCEDURE Advance(sys: NBodySystem; dt: REAL64);
  VAR i, j: INT32; iBody, jBody: Body;
      dx, dy, dz, dSquared, distance, mag: REAL64;
BEGIN
  FOR i := 0 TO Count - 1 DO
    iBody := sys.bodies[i];
    FOR j := i + 1 TO Count - 1 DO
      jBody := sys.bodies[j];
      dx := iBody.x - jBody.x;
      dy := iBody.y - jBody.y;
      dz := iBody.z - jBody.z;

      dSquared := dx * dx + dy * dy + dz * dz;
      distance := MathL.sqrt(dSquared);
      mag := dt / (dSquared * distance);

      iBody.vx := iBody.vx - (dx * jBody.mass * mag);
      iBody.vy := iBody.vy - (dy * jBody.mass * mag);
      iBody.vz := iBody.vz - (dz * jBody.mass * mag);

      jBody.vx := jBody.vx + (dx * iBody.mass * mag);
      jBody.vy := jBody.vy + (dy * iBody.mass * mag);
      jBody.vz := jBody.vz + (dz * iBody.mass * mag);
    END;
  END;

  FOR i := 0 TO Count - 1 DO
    iBody := sys.bodies[i];
    iBody.x := iBody.x + dt * iBody.vx;
    iBody.y := iBody.y + dt * iBody.vy;
    iBody.z := iBody.z + dt * iBody.vz;
  END;
END Advance;

PROCEDURE Energy(sys: NBodySystem): REAL64;
  VAR e: REAL64; i, j: INT32; iBody, jBody: Body;
      dx, dy, dz, distance: REAL64;
BEGIN
  e := 0.0;
  FOR i := 0 TO Count - 1 DO
    iBody := sys.bodies[i];
    e := e + 0.5 * iBody.mass *
         (iBody.vx * iBody.vx + iBody.vy * iBody.vy + iBody.vz * iBody.vz);

    FOR j := i + 1 TO Count - 1 DO
      jBody := sys.bodies[j];
      dx := iBody.x - jBody.x;
      dy := iBody.y - jBody.y;
      dz := iBody.z - jBody.z;
      distance := MathL.sqrt(dx * dx + dy * dy + dz * dz);
      e := e - (iBody.mass * jBody.mass) / distance;
    END;
  END;
  RETURN e
END Energy;

PROCEDURE VerifyResult(result: REAL64; innerIterations: INT32): BOOLEAN;
BEGIN
  IF innerIterations = 250000 THEN
    RETURN ABS(result) - 0.1690859889909308 < 0.00000000000000005
  ELSIF innerIterations = 1 THEN
    RETURN ABS(result) - 0.16907495402506745 < 0.00000000000000005
  ELSE
    Out.String("No verification result for "); Out.Int(innerIterations, 0); Out.String(" found"); Out.Ln;
    Out.String("Result is: "); Out.LongReal(result, 20); Out.Ln;
    RETURN FALSE
  END
END VerifyResult;

PROCEDURE InnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
  VAR
    system: NBodySystem;
    i: INT32;
BEGIN
  system := CreateNBodySystem();
  i := 0;
  WHILE i < innerIterations DO
    Advance(system, 0.01);
    INC(i);
  END;
  RETURN VerifyResult(Energy(system), innerIterations)
END InnerBenchmarkLoop;

PROCEDURE Create*(): Benchmark.Benchmark;
  VAR n: NBody;
BEGIN
  NEW(n);
  n.InnerBenchmarkLoop := InnerBenchmarkLoop;
  RETURN n
END Create;

END NBody.
