(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
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

MODULE Bounce;

(*
  This module implements the Bounce benchmark. It simulates a number of balls
  bouncing within a 2D box and counts the total number of bounces.
*)

IMPORT Benchmark, SOM, Random, Out;

CONST
  NumBalls = 100;
  NumIterations = 50;

TYPE
  INT32 = SOM.INT32; 

  (* Private record type for a single Ball. It does not need to be exported.
     It inherits from SOM.Object for consistency, though not strictly required
     by this benchmark's implementation. *)
  Ball = POINTER TO BallDesc;
  BallDesc = RECORD (SOM.ObjectDesc)
    x, y, xVel, yVel: INT32;
  END;

  Bounce = POINTER TO BounceDesc;
  BounceDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  (* Helper record to wrap the integer result into a SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
    value: INT32;
  END;

(* --- Private Helper Procedures (Not Exported) --- *)

(* Creates a new Ball with random initial position and velocity. *)
PROCEDURE CreateBall(random: Random.Random): Ball;
  VAR b: Ball;
BEGIN
  NEW(b);
  b.x    := Random.Next(random) MOD 500;
  b.y    := Random.Next(random) MOD 500;
  b.xVel := (Random.Next(random) MOD 300) - 150;
  b.yVel := (Random.Next(random) MOD 300) - 150;
  RETURN b;
END CreateBall;

(* Updates a ball's position and checks for boundary collisions.
   Returns TRUE if the ball bounced. *)
PROCEDURE DoBounce(b: Ball): BOOLEAN;
  VAR
    xLimit, yLimit: INT32;
    bounced: BOOLEAN;
BEGIN
  xLimit := 500; yLimit := 500;
  bounced := FALSE;

  b.x := b.x + b.xVel;
  b.y := b.y + b.yVel;

  IF b.x > xLimit THEN
    b.x := xLimit;
    b.xVel := -ABS(b.xVel);
    bounced := TRUE;
  END;

  IF b.x < 0 THEN
    b.x := 0;
    b.xVel := ABS(b.xVel);
    bounced := TRUE;
  END;

  IF b.y > yLimit THEN
    b.y := yLimit;
    b.yVel := -ABS(b.yVel);
    bounced := TRUE;
  END;

  IF b.y < 0 THEN
    b.y := 0;
    b.yVel := ABS(b.yVel);
    bounced := TRUE;
  END;

  RETURN bounced;
END DoBounce;

(* --- Public Procedures --- *)

(* Public procedure to run the main benchmark logic. *)
PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
  VAR
    random: Random.Random;
    balls: POINTER TO ARRAY OF Ball;
    bounces: INT32;
    i, j: INT32; (* Use distinct loop variables 'i' and 'j' *)
    resultObj: IntegerObject;
BEGIN
  random := Random.Create();
  bounces := 0;

  NEW(balls, NumBalls);
  FOR i := 0 TO NumBalls - 1 DO
    balls[i] := CreateBall(random);
  END;

  (* Outer loop uses 'i' *)
  FOR i := 1 TO NumIterations DO
    (* Inner loop uses 'j' *)
    FOR j := 0 TO NumBalls - 1 DO
      IF DoBounce(balls[j]) THEN
        INC(bounces);
      END;
    END;
  END;

  (* Wrap the final count in an object to return. *)
  NEW(resultObj);
  resultObj.value := bounces;
  RETURN resultObj;
END DoBenchmark;


(* Public procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 1331;
  ELSE
    Out.String("Bounce verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new Bounce benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR b: Bounce;
BEGIN
  NEW(b);
  (* Assign this module's procedures to the polymorphic procedure variables. *)
  b.DoBenchmark := DoBenchmark;
  b.VerifyResult := VerifyResult;
  b.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN b;
END Create;

END Bounce.

