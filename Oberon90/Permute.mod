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

MODULE Permute;

(*
  This module implements the Permute benchmark, which recursively calculates
  permutations of a small array and counts the number of operations.
*)

IMPORT Benchmark, SOM, Out;

CONST
  VectorSize = 6;

TYPE
  (* Publicly exported record type for the Permute benchmark.
     It inherits from the base Benchmark type and holds the state
     for the permutation algorithm. *)
  Permute* = POINTER TO PermuteDesc;
  PermuteDesc* = RECORD (Benchmark.BenchmarkDesc)
    count: INTEGER;
    v: POINTER TO ARRAY OF INTEGER;
  END;

  (* Helper record to wrap the integer result into a SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
    value: INTEGER;
  END;

(* Swaps two elements in the benchmark's vector. *)
PROCEDURE Swap(p: Permute; i, j: INTEGER);
  VAR tmp: INTEGER;
BEGIN
  tmp := p.v[i];
  p.v[i] := p.v[j];
  p.v[j] := tmp;
END Swap;

(* The core recursive permutation algorithm.
   This is a private implementation detail. *)
PROCEDURE PermuteRec(p: Permute; n: INTEGER);
  VAR i: INTEGER;
BEGIN
  INC(p.count);
  IF n # 0 THEN
    PermuteRec(p, n - 1);
    FOR i := n - 1 TO 0 BY -1 DO
      Swap(p, n - 1, i);
      PermuteRec(p, n - 1);
      Swap(p, n - 1, i); (* Swap back to restore state for next iteration *)
    END;
  END;
END PermuteRec;


(* procedure to run the main benchmark logic. *)
PROCEDURE DoBenchmark(b: Benchmark.Benchmark): SOM.Object;
  VAR
    p: Permute;
    resultObj: IntegerObject;
BEGIN
  p := b(Permute); (* Type cast from base Benchmark to our specific type *)

  p.count := 0;
  NEW(p.v, VectorSize);
  PermuteRec(p, VectorSize);

  (* Wrap the final count in an object to return. *)
  NEW(resultObj);
  resultObj.value := p.count;
  RETURN resultObj;
END DoBenchmark;

(* procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 8660;
  ELSE
    Out.String("Permute verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new Permute benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR p: Permute;
BEGIN
  NEW(p);
  p.DoBenchmark := DoBenchmark;
  p.VerifyResult    := VerifyResult;
  p.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN p;
END Create;

END Permute.

