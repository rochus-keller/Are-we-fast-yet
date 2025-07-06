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
 
 MODULE Storage;

(*
  This module implements the Storage benchmark, which recursively builds a
  tree of arrays to measure memory allocation and garbage collection performance.
  The recursive array structure is modeled using SOM.Vectors containing other SOM.Vectors.
*)

IMPORT Benchmark, SOM, Random, Out;

TYPE
  INT32  = SOM.INT32;
  (* Publicly exported record type for the Storage benchmark. *)
  Storage* = POINTER TO StorageDesc;
  StorageDesc* = RECORD (Benchmark.BenchmarkDesc)
    count: INT32;
  END;

  (* Helper record to wrap the integer result into a SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
    value: INT32;
  END;

(* --- Private Helper Procedures (Not Exported) --- *)

(* The core recursive function to build the tree structure.
   This is a private implementation detail of the benchmark. *)
PROCEDURE BuildTreeDepth(s: Storage; depth: INT32; random: Random.Random): SOM.Object;
  VAR
    vec: SOM.Vector;
    i: INT32;
BEGIN
  INC(s.count);
  IF depth = 1 THEN
    (* Base case: create a vector of random size. Its elements will be NIL. *)
    vec := SOM.CreateVector(Random.Next(random) MOD 10 + 1);
    RETURN vec;
  ELSE
    (* Recursive step: create a vector of 4 elements, where each element
       is a recursively built tree (which is another vector). *)
    vec := SOM.CreateVector(4);
    FOR i := 0 TO 3 DO
      SOM.VectorAtPut(vec, i, BuildTreeDepth(s, depth - 1, random));
    END;
    RETURN vec;
  END;
END BuildTreeDepth;

(* procedure to run the main benchmark logic. *)
PROCEDURE DoBenchmark(b: Benchmark.Benchmark): SOM.Object;
  VAR
    s: Storage;
    random: Random.Random;
    resultObj: IntegerObject;
BEGIN
  s := b(Storage); (* Type cast from base Benchmark to our specific type *)
  random := Random.Create();

  s.count := 0;
  BuildTreeDepth(s, 7, random); (* The returned tree is discarded; we only care about the count *)

  (* Wrap the final count in an object to return. *)
  NEW(resultObj);
  resultObj.value := s.count;
  RETURN resultObj;
END DoBenchmark;

(* procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 5461;
  ELSE
    Out.String("Storage verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new Storage benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR s: Storage;
BEGIN
  NEW(s);
  s.DoBenchmark := DoBenchmark;
  s.VerifyResult := VerifyResult;
  s.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN s;
END Create;

END Storage.

