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

MODULE List;

(*
This module implements the List benchmark. It tests the performance
of object allocation and garbage collection by creating and recursively
processing linked lists.
*)

IMPORT Benchmark, SOM, Out;

TYPE
  Element = POINTER TO ElementDesc;
  ElementDesc* = RECORD (SOM.ObjectDesc)
                  val: INTEGER;
                  next: Element;
                  END;
  
  List = POINTER TO ListDesc;
  ListDesc* = RECORD (Benchmark.BenchmarkDesc) END;
  
  (* Helper record to wrap the integer result into a SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
                      value: INTEGER;
                      END;

(* --- Private Helper Procedures (Not Exported) --- *)

(* Recursively calculates the length of a list. *)
PROCEDURE ElementLength(e: Element): INTEGER;
BEGIN
  IF e.next = NIL THEN
    RETURN 1;
  ELSE
    RETURN 1 + ElementLength(e.next);
  END;
END ElementLength;

(* Recursively creates a linked list of a given length. *)
PROCEDURE MakeList(length: INTEGER): Element;
VAR e: Element;
BEGIN
  IF length = 0 THEN
    RETURN NIL;
  ELSE
    NEW(e);
    e.val := length;
    e.next := MakeList(length - 1);
    RETURN e;
  END;
END MakeList;

(* Checks if list x is shorter than list y. *)
PROCEDURE IsShorterThan(x, y: Element): BOOLEAN;
VAR xTail, yTail: Element;
BEGIN
  xTail := x;
  yTail := y;
  WHILE yTail # NIL DO
    IF xTail = NIL THEN RETURN TRUE END;
    xTail := xTail.next;
    yTail := yTail.next;
  END;
  RETURN FALSE;
END IsShorterThan;

(* The core, mutually recursive algorithm of the benchmark. *)
PROCEDURE Tail(x, y, z: Element): Element;
BEGIN
  IF IsShorterThan(y, x) THEN
    RETURN Tail(Tail(x.next, y, z),
      Tail(y.next, z, x),
      Tail(z.next, x, y));
  ELSE
    RETURN z;
  END;
END Tail;

(* procedure to run the main benchmark logic. *)
PROCEDURE DoBenchmark(b: Benchmark.Benchmark): SOM.Object;
VAR
  resultList: Element;
  resultObj: IntegerObject;
BEGIN
  resultList := Tail(MakeList(15), MakeList(10), MakeList(6));

  NEW(resultObj);
  resultObj.value := ElementLength(resultList);
  RETURN resultObj;
END DoBenchmark;

(* procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 10;
  ELSE
    Out.String("List verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new List benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR l: List;
BEGIN
  NEW(l);
  (* This benchmark uses the default loop but overrides the benchmark and verify procedures. *)
  l.DoBenchmark := DoBenchmark;
  l.VerifyResult := VerifyResult;
  l.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN l;
END Create;

END List.
