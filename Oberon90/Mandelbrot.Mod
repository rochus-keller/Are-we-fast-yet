(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
 *
// Copyright (C) 2004-2013 Brent Fulgham
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//   * Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * Neither the name of "The Computer Language Benchmarks Game" nor the name
//     of "The Computer Language Shootout Benchmarks" nor the names of its
//     contributors may be used to endorse or promote products derived from this
//     software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// The Computer Language Benchmarks Game
// http://benchmarksgame.alioth.debian.org
//
//  contributed by Karl von Laudermann
//  modified by Jeremy Echols
//  modified by Detlef Reichl
//  modified by Joseph LaFata
//  modified by Peter Zotov
*)

MODULE Mandelbrot;

(*
  This module implements the Mandelbrot benchmark. It calculates a view of the
  Mandelbrot set and performs a checksum on the resulting data. It's a
  compute-intensive benchmark focusing on floating-point and bitwise operations.
  
  This benchmark uses a custom inner loop, which is implemented by overriding
  the default 'innerLoopProc' from the base Benchmark type.
*)

IMPORT Benchmark, SOM, SYSTEM, Out;

TYPE
  INT32 = SOM.INT32;
  F64 = SOM.F64;
  Mandelbrot* = POINTER TO MandelbrotDesc;
  MandelbrotDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  (* Helper record to wrap the integer result into a SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
    value: INT32;
  END;

(* --- Private Helper Procedures (Not Exported) --- *)

PROCEDURE DoMandelbrot(size: INT32): INT32;
  VAR
    sum, byteAcc, bitNum: INT32;
    y, x, z: INT32;
    ci, cr: INT32;
    zr, zi, zrzr, zizi: F64;
    notDone: BOOLEAN;
    escape: INT32;
BEGIN
  sum := 0; byteAcc := 0; bitNum := 0;

  y := 0;
  WHILE y < size DO
    ci := ENTIER((2.0 * y / size) - 1.0);
    x := 0;
    WHILE x < size DO
      zr := 0.0; zrzr := 0.0;
      zi := 0.0; zizi := 0.0;
      cr := ENTIER((2.0 * x / size) - 1.5);

      z := 0; notDone := TRUE; escape := 0;
      WHILE notDone & (z < 50) DO
        zr := zrzr - zizi + cr;
        zi := 2.0 * zr * zi + ci;

        zrzr := zr * zr;
        zizi := zi * zi;

        IF (zrzr + zizi) > 4.0 THEN
          notDone := FALSE;
          escape := 1;
        END;
        INC(z);
      END;

      byteAcc := SYSTEM.LSH(byteAcc, 1) + escape; (* byte_acc << 1 *)
      INC(bitNum);
      IF bitNum = 8 THEN
        sum := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, sum) / SYSTEM.VAL(SET, byteAcc)); (* sum XOR byte_acc *)
        byteAcc := 0; bitNum := 0;
      ELSIF x = size - 1 THEN
        byteAcc := SYSTEM.LSH(byteAcc, 8 - bitNum);
        sum := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, sum) / SYSTEM.VAL(SET, byteAcc)); (* sum XOR byte_acc *)
        byteAcc := 0; bitNum := 0;
      END;

      INC(x);
    END;
    INC(y);
  END;
  RETURN sum;
END DoMandelbrot;

(* The verification depends on the number of iterations. *)
PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object; innerIterations: INTEGER): BOOLEAN;
  VAR val: INT32;
BEGIN
  IF result IS IntegerObject THEN
    val := result(IntegerObject).value;
    IF innerIterations = 500 THEN RETURN val = 191
    ELSIF innerIterations = 750 THEN RETURN val = 50
    ELSIF innerIterations = 1 THEN RETURN val = 128
    ELSE
      Out.String("No verification result for "); Out.Int(innerIterations, 0); Out.String(" found"); Out.Ln;
      Out.String("Result is: "); Out.Int(val, 0); Out.Ln;
      RETURN FALSE;
    END;
  ELSE
    Out.String("Mandelbrot verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* This is a special implementation of the inner benchmark loop,
   as the Mandelbrot verification depends on the iteration count. *)
PROCEDURE InnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
  VAR
    mandelbrotResult: INT32;
    resultObj: IntegerObject;
BEGIN
  mandelbrotResult := DoMandelbrot(innerIterations);
  
  NEW(resultObj);
  resultObj.value := mandelbrotResult;
  
  (* The verification logic is called directly here. *)
  RETURN VerifyResult(b, resultObj, innerIterations);
END InnerBenchmarkLoop;

(* Public factory procedure to create a new Mandelbrot benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR m: Mandelbrot;
BEGIN
  NEW(m);
  (* This benchmark has a custom loop, so we assign its specific procedure
     to the 'InnerBenchmarkLoop' field, overriding the default behavior. *)
  m.InnerBenchmarkLoop := InnerBenchmarkLoop;
  RETURN m;
END Create;

END Mandelbrot.


