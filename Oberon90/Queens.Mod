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
 
MODULE Queens;

(*
  This module implements the Queens benchmark, which solves the 8-Queens
  problem using a recursive backtracking algorithm. 
*)

IMPORT Benchmark, SOM, Out;

TYPE
  INT32  = SOM.INT32;
  (* Publicly exported record type for the Queens benchmark.
     It inherits from the base Benchmark type and holds the state
     of the chessboard as arrays. *)
  Queens* = POINTER TO QueensDesc;
  QueensDesc* = RECORD (Benchmark.BenchmarkDesc)
    freeRows:  POINTER TO ARRAY OF BOOLEAN;
    freeMaxs:  POINTER TO ARRAY OF BOOLEAN;
    freeMins:  POINTER TO ARRAY OF BOOLEAN;
    queenRows: POINTER TO ARRAY OF INT32;
  END;

  (* A helper record to wrap a BOOLEAN result so it can be returned
     as a generic SOM.Object, as required by the benchmark framework. *)
  BooleanObject = POINTER TO BooleanObjectDesc;
  BooleanObjectDesc = RECORD (SOM.ObjectDesc)
    value: BOOLEAN;
  END;

(* Checks if a given position (row, column) is free. *)
PROCEDURE GetRowColumn(q: Queens; r, c: INT32): BOOLEAN;
BEGIN
  RETURN q.freeRows[r] & q.freeMaxs[c + r] & q.freeMins[c - r + 7];
END GetRowColumn;

(* Marks a given position (row, column) and its diagonals as either
   occupied or free. *)
PROCEDURE SetRowColumn(q: Queens; r, c: INT32; v: BOOLEAN);
BEGIN
  q.freeRows[r]         := v;
  q.freeMaxs[c + r]     := v;
  q.freeMins[c - r + 7] := v;
END SetRowColumn;

(* The core recursive backtracking algorithm to place queens. *)
PROCEDURE PlaceQueen(q: Queens; c: INT32): BOOLEAN;
  VAR r: INT32;
BEGIN
  FOR r := 0 TO 7 DO
    IF GetRowColumn(q, r, c) THEN
      q.queenRows[r] := c;
      SetRowColumn(q, r, c, FALSE);

      IF c = 7 THEN
        RETURN TRUE; (* Successfully placed all queens *)
      END;

      IF PlaceQueen(q, c + 1) THEN
        RETURN TRUE; (* Recursive call was successful *)
      END;

      (* Backtrack: reset the board state *)
      SetRowColumn(q, r, c, TRUE);
    END;
  END;
  RETURN FALSE; (* Failed to place a queen in this column *)
END PlaceQueen;

(* Sets up the board and initiates the solving process for one run. *)
PROCEDURE RunQueens(q: Queens): BOOLEAN;
VAR i: INT32;
BEGIN
  NEW(q.freeRows, 8);
  NEW(q.freeMaxs, 16);
  NEW(q.freeMins, 16);
  NEW(q.queenRows, 8);
  FOR i := 0 TO 8-1 DO
      q.freeRows[i] := TRUE;
      q.queenRows[i] := -1
  END;
  FOR i := 0 TO 16-1 DO
      q.freeMaxs[i] := TRUE;
      q.freeMins[i] := TRUE
  END;
  RETURN PlaceQueen(q, 0);
END RunQueens;

(* procedure to run the main benchmark logic. It runs the
   solver 10 times, as specified in the original Crystal code. *)
PROCEDURE DoBenchmark(b: Benchmark.Benchmark): SOM.Object;
  VAR
    q: Queens;
    result: BOOLEAN;
    i: INT32;
    resultObj: BooleanObject;
BEGIN
  q := b(Queens); (* Type cast from base Benchmark to our specific Queens type *)
  result := TRUE;
  FOR i := 1 TO 10 DO
    result := result & RunQueens(q);
  END;

  (* Wrap the final boolean result in an object to return. *)
  NEW(resultObj);
  resultObj.value := result;
  RETURN resultObj;
END DoBenchmark;

(* procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  IF result IS BooleanObject THEN
    RETURN result(BooleanObject).value; (* The benchmark is successful if the boolean value is TRUE *)
  ELSE
    (* This case should not be reached if the framework is used correctly. *)
    Out.String("Queens verification failed: result is not a BooleanObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new Queens benchmark instance. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR q: Queens;
BEGIN
  NEW(q);
  (* Assign the local, benchmark-specific procedures to the procedure
     variables of the parent Benchmark type to achieve polymorphic behavior. *)
  q.DoBenchmark := DoBenchmark;
  q.VerifyResult    := VerifyResult;
  q.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN q;
END Create;

END Queens.

