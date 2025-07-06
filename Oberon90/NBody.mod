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
  PI* = 3.141592653589793;
  SOLAR_MASS* = 4.0 * PI * PI;
  DAYS_PER_YEAR* = 365.24;

TYPE
  REAL64 = SOM.F64; 
  INT32  = SOM.INT32;

  (* Record for a single celestial body. *)
  Body = POINTER TO BodyDesc;
  BodyDesc = RECORD(SOM.ObjectDesc)
    x, y, z, vx, vy, vz, mass: REAL64;
  END;
  
  (* Record to manage the system of bodies. *)
  NBodySystem = POINTER TO NBodySystemDesc;
  NBodySystemDesc = RECORD(SOM.ObjectDesc)
    bodies: POINTER TO ARRAY OF Body;
  END;

  (* Publicly exported record type for the NBody benchmark itself. *)
  NBody* = POINTER TO NBodyDesc;
  NBodyDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  (* Helper record to wrap the LONGREAL result into a SOM.Object. *)
  RealObject = POINTER TO RealObjectDesc;
  RealObjectDesc = RECORD(SOM.ObjectDesc)
    value: REAL64;
  END;

(* Factory procedures to create pre-defined celestial bodies. *)
PROCEDURE NewBody(x, y, z, vx, vy, vz, mass: REAL64): Body;
  VAR b: Body;
BEGIN
  NEW(b);
  b.x := x;
  b.y := y;
  b.z := z;
  b.vx := vx * DAYS_PER_YEAR;
  b.vy := vy * DAYS_PER_YEAR;
  b.vz := vz * DAYS_PER_YEAR;
  b.mass := mass * SOLAR_MASS;
  RETURN b;
END NewBody;

PROCEDURE Jupiter(): Body;
BEGIN
  RETURN NewBody(4.8414314424647209, -1.16032004402742839, -0.103622044471123109,
                 0.00166007664274403694, 0.00769901118419740425, -0.0000690460016972063023,
                 0.000954791938424326609);
END Jupiter;

PROCEDURE Saturn(): Body;
BEGIN
  RETURN NewBody(8.34336671824457987, 4.12479856412430479, -0.403523417114321381,
                 -0.00276742510726862411, 0.00499852801234917238, 0.0000230417297573763929,
                 0.000285885980666130812);
END Saturn;

PROCEDURE Uranus(): Body;
BEGIN
  RETURN NewBody(12.894369562139131, -15.1111514016986312, -0.223307578892655734,
                 0.00296460137564761618, 0.0023784717395948095, -0.0000296589568540237556,
                 0.0000436624404335156298);
END Uranus;

PROCEDURE Neptune(): Body;
BEGIN
  RETURN NewBody(15.3796971148509165, -25.9193146099879641, 0.179258772950371181,
                 0.00268067772490389322, 0.00162824170038242295, -0.000095159225451971587,
                 0.0000515138902046611451);
END Neptune;

PROCEDURE Sun(): Body;
BEGIN
  RETURN NewBody(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
END Sun;

(* Offsets the sun's momentum to balance the system. *)
PROCEDURE OffsetMomentum(sun: Body; px, py, pz: REAL64);
BEGIN
  sun.vx := -px / SOLAR_MASS;
  sun.vy := -py / SOLAR_MASS;
  sun.vz := -pz / SOLAR_MASS;
END OffsetMomentum;

(* Creates the complete system of bodies. *)
PROCEDURE CreateNBodySystem(): NBodySystem;
  VAR sys: NBodySystem; px, py, pz: REAL64; i: INT32; b: Body;
BEGIN
  NEW(sys);
  NEW(sys.bodies, 5);
  sys.bodies[0] := Sun();
  sys.bodies[1] := Jupiter();
  sys.bodies[2] := Saturn();
  sys.bodies[3] := Uranus();
  sys.bodies[4] := Neptune();
  
  px := 0.0; py := 0.0; pz := 0.0;
  FOR i := 0 TO LEN(sys.bodies^) - 1 DO
    b := sys.bodies[i];
    px := px + b.vx * b.mass;
    py := py + b.vy * b.mass;
    pz := pz + b.vz * b.mass;
  END;
  OffsetMomentum(sys.bodies[0], px, py, pz);
  RETURN sys;
END CreateNBodySystem;

(* Advances the simulation by one time step 'dt'. *)
PROCEDURE Advance(sys: NBodySystem; dt: REAL64);
  VAR i, j: INT32; iBody, jBody: Body; dx, dy, dz, dSquared, distance, mag: REAL64;
BEGIN
  (* Calculate gravitational forces *)
  FOR i := 0 TO LEN(sys.bodies^) - 1 DO
    iBody := sys.bodies[i];
    FOR j := i + 1 TO LEN(sys.bodies^) - 1 DO
      jBody := sys.bodies[j];
      dx := iBody.x - jBody.x;
      dy := iBody.y - jBody.y;
      dz := iBody.z - jBody.z;

      dSquared := (dx * dx) + (dy * dy) + (dz * dz);
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

  (* Update body positions *)
  FOR i := 0 TO LEN(sys.bodies^) - 1 DO
    iBody := sys.bodies[i];
    iBody.x := iBody.x + dt * iBody.vx;
    iBody.y := iBody.y + dt * iBody.vy;
    iBody.z := iBody.z + dt * iBody.vz;
  END;
END Advance;

(* Calculates the total energy of the system. *)
PROCEDURE Energy(sys: NBodySystem): REAL64;
  VAR e: REAL64; i, j: INT32; iBody, jBody: Body; dx, dy, dz, distance: REAL64;
BEGIN
  e := 0.0;
  FOR i := 0 TO LEN(sys.bodies^) - 1 DO
    iBody := sys.bodies[i];
    e := e + 0.5 * iBody.mass * ((iBody.vx * iBody.vx) + (iBody.vy * iBody.vy) + (iBody.vz * iBody.vz));
    
    FOR j := i + 1 TO LEN(sys.bodies^) - 1 DO
      jBody := sys.bodies[j];
      dx := iBody.x - jBody.x;
      dy := iBody.y - jBody.y;
      dz := iBody.z - jBody.z;
      distance := MathL.sqrt((dx * dx) + (dy * dy) + (dz * dz));
      e := e - (iBody.mass * jBody.mass) / distance;
    END;
  END;
  RETURN e;
END Energy;

(* A custom inner loop for this benchmark. *)
PROCEDURE NBodyInnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
  VAR
    system: NBodySystem;
    i: INT32;
    energyResult: REAL64;
    resultObj: RealObject;
BEGIN
  system := CreateNBodySystem();

  i := 0;
  WHILE i < innerIterations DO
    Advance(system, 0.01);
    INC(i);
  END;
  
  energyResult := Energy(system);
  
  NEW(resultObj);
  resultObj.value := energyResult;
  RETURN VerifyResult(b, resultObj, innerIterations);
END NBodyInnerBenchmarkLoop;

(* Verification depends on the iteration count. *)
PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object; innerIterations: INT32): BOOLEAN;
  VAR val: REAL64;
BEGIN
  WITH result: RealObject DO
    val := result.value;
    IF innerIterations = 250000 THEN RETURN ABS(val - (-0.1690859889909308)) < 1.0E-14
    ELSIF innerIterations = 1 THEN RETURN ABS(val - (-0.16907495402506745)) < 1.0E-14
    ELSE
      Out.String("No verification result for "); Out.Int(innerIterations, 0); Out.String(" found"); Out.Ln;
      Out.String("Result is: "); Out.LongReal(val, 20); Out.Ln;
      RETURN FALSE;
    END;
  ELSE
    Out.String("NBody verification failed: result is not a RealObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new NBody benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR n: NBody;
BEGIN
  NEW(n);
  (* This benchmark has a custom loop and verification, so we assign its procedures. *)
  n.InnerBenchmarkLoop := NBodyInnerBenchmarkLoop;
  RETURN n;
END Create;

END NBody.

