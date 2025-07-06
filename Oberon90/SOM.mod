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
 
MODULE SOM;

IMPORT SYSTEM, Out;

CONST
  INITIAL_VECTOR_SIZE* = 50;
  INITIAL_SET_SIZE*    = 10;
  INITIAL_CAPACITY*    = 16;

TYPE
  INT32* = LONGINT;
  F64* = LONGREAL;

  (* The base type for all objects in the benchmark suite. *)
  Object* = POINTER TO ObjectDesc;
  ObjectDesc* = RECORD END;

  (* Generic procedure types for collection iteration.
     The 'data' parameter is crucial for passing context. *)
  Context* = POINTER TO RECORD END;
  ValueIterator* = PROCEDURE (item: Object; data: Context);
  TestIterator*  = PROCEDURE (item: Object; data: Context): BOOLEAN;
  Compare*       = PROCEDURE (a, b: Object): INTEGER;

  (* Forward declarations for the collection types. *)
  Vector*     = POINTER TO VectorDesc;
  Set*        = POINTER TO SetDesc;
  Dictionary* = POINTER TO DictionaryDesc;

  (* --- Record types defining the structure of collections --- *)
  VectorDesc* = RECORD (ObjectDesc)
    storage: POINTER TO ARRAY OF Object;
    firstIdx, lastIdx: INT32;
  END;

  SetDesc* = RECORD (ObjectDesc)
    items: Vector;
  END;

  (* Helper records for passing context to iterators *)
  SetContainsContext = POINTER TO SetContainsContextDesc;
  SetContainsContextDesc = RECORD (Context)
    objToFind: Object;
    found: BOOLEAN;
  END;
  
  VectorRemoveContext = POINTER TO VectorRemoveContextDesc;
  VectorRemoveContextDesc = RECORD
    objToRemove: Object;
    found: BOOLEAN;
  END;
  
  Entry = POINTER TO EntryDesc;
  EntryDesc = RECORD (ObjectDesc)
    hash: INT32;
    key, value: Object;
    next: Entry;
  END;

  (* A generic hash function. *)
  HashProc = PROCEDURE (obj: Object): INT32;

  DictionaryDesc = RECORD (ObjectDesc)
    buckets: POINTER TO ARRAY OF Entry;
    size: INT32;
    hashFunc: HashProc;
  END;

(* --- Default Equality and Hashing --- *)

PROCEDURE ObjectsEqual*(a, b: Object): BOOLEAN;
BEGIN
  (* Default behavior is pointer equality. Specific types can override this. *)
  RETURN a = b;
END ObjectsEqual;

PROCEDURE DefaultHash*(obj: Object): INT32;
  VAR h: INT32;
BEGIN
  h := SYSTEM.VAL(INT32, obj); (* Address as hash *)
  RETURN SYSTEM.VAL(INT32, SYSTEM.VAL(SET, h) / SYSTEM.VAL(SET, SYSTEM.LSH(h, -16))); (* h XOR (h >>> 16) *)
END DefaultHash;

(* --- Private Helper Procedures for Iteration --- *)

(* Top-level procedure for the Set.Contains check. Can be legally passed as an argument. *)
PROCEDURE SetContainsCheck(item: Object; data: Context): BOOLEAN;
  VAR context: SetContainsContext;
BEGIN
  context := data(SetContainsContext); 
  IF ObjectsEqual(item, context.objToFind) THEN
    context.found := TRUE;
    RETURN TRUE; (* Stop iteration early *)
  ELSE
    RETURN FALSE;
  END;
END SetContainsCheck;

(* --- Vector Procedures --- *)

PROCEDURE EnlargeVector(v: Vector; minSize: INT32);
  VAR newLength: INT32;
      newStorage: POINTER TO ARRAY OF Object;
      i: INT32;
BEGIN
  newLength := LEN(v.storage^);
  IF newLength = 0 THEN newLength := 1 END;
  WHILE newLength <= minSize DO
    newLength := newLength * 2;
  END;
  NEW(newStorage, newLength);
  FOR i := 0 TO LEN(v.storage^) - 1 DO
    newStorage[i] := v.storage[i];
  END;
  v.storage := newStorage;
END EnlargeVector;

PROCEDURE CreateVector*(initialSize: INT32): Vector;
  VAR v: Vector; size: INT32;
BEGIN
  NEW(v);
  IF initialSize = 0 THEN size := INITIAL_VECTOR_SIZE ELSE size := initialSize END;
  NEW(v.storage, size);
  v.firstIdx := 0; v.lastIdx := 0;
  RETURN v;
END CreateVector;

PROCEDURE VectorAt*(v: Vector; idx: INT32): Object;
BEGIN
  IF (idx >= v.firstIdx) & (idx < v.lastIdx) THEN RETURN v.storage[idx] END;
  RETURN NIL;
END VectorAt;

PROCEDURE VectorAtPut*(v: Vector; idx: INT32; val: Object);
BEGIN
  IF idx >= LEN(v.storage^) THEN
    EnlargeVector(v, idx);
  END;
  v.storage[idx] := val;
  IF v.lastIdx < idx + 1 THEN
    v.lastIdx := idx + 1;
  END;
END VectorAtPut;

PROCEDURE VectorAppend*(v: Vector; elem: Object);
  VAR newStorage: POINTER TO ARRAY OF Object; i: INT32;
BEGIN
  IF v.lastIdx >= LEN(v.storage^) THEN
    NEW(newStorage, LEN(v.storage^) * 2);
    FOR i := 0 TO LEN(v.storage^) - 1 DO newStorage[i] := v.storage[i] END;
    v.storage := newStorage;
  END;
  v.storage[v.lastIdx] := elem;
  INC(v.lastIdx);
END VectorAppend;

PROCEDURE VectorIsEmpty*(v: Vector): BOOLEAN;
BEGIN
  RETURN v.lastIdx = v.firstIdx;
END VectorIsEmpty;

PROCEDURE VectorSize*(v: Vector): INT32;
BEGIN
  RETURN v.lastIdx - v.firstIdx;
END VectorSize;

PROCEDURE VectorForEach*(v: Vector; p: ValueIterator; data: Context);
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    p(v.storage[i], data);
  END;
END VectorForEach;

PROCEDURE VectorHasSome*(v: Vector; p: TestIterator; data: Context): BOOLEAN;
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    IF p(v.storage[i], data) THEN RETURN TRUE END;
  END;
  RETURN FALSE;
END VectorHasSome;

PROCEDURE VectorRemove*(v: Vector; obj: Object): BOOLEAN;
  VAR
    newStorage: POINTER TO ARRAY OF Object;
    newLast, i, j: INT32;
    found: BOOLEAN;
BEGIN
  found := FALSE;
  i := v.firstIdx;
  WHILE ~found & (i < v.lastIdx) DO
    IF ObjectsEqual(v.storage[i], obj) THEN found := TRUE ELSE INC(i) END;
  END;

  IF found THEN
    NEW(newStorage, LEN(v.storage^));
    newLast := 0;
    FOR j := v.firstIdx TO v.lastIdx - 1 DO
      IF j # i THEN
        newStorage[newLast] := v.storage[j];
        INC(newLast);
      END;
    END;
    v.storage := newStorage;
    v.lastIdx := newLast;
    v.firstIdx := 0;
  END;
  RETURN found;
END VectorRemove;

(* --- Set Procedures --- *)

PROCEDURE CreateSet*(initialSize: INT32): Set;
  VAR s: Set;
BEGIN
  NEW(s);
  s.items := CreateVector(initialSize);
  RETURN s;
END CreateSet;

PROCEDURE SetSize*(s: Set): INT32;
BEGIN
  RETURN VectorSize(s.items);
END SetSize;

PROCEDURE SetContains*(s: Set; obj: Object): BOOLEAN;
  VAR context: SetContainsContext;
BEGIN
  NEW(context);
  context.objToFind := obj;
  context.found := FALSE;
  (* Call VectorHasSome, passing our top-level iterator and a pointer to the context record *)
  IF VectorHasSome(s.items, SetContainsCheck, context) THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END SetContains;

PROCEDURE SetAdd*(s: Set; obj: Object);
BEGIN
  IF ~SetContains(s, obj) THEN
    VectorAppend(s.items, obj);
  END;
END SetAdd;

(* --- Dictionary Procedures (stubbed for brevity) --- *)
PROCEDURE CreateDictionary*(): Dictionary;
  VAR d: Dictionary;
BEGIN
  NEW(d);
  RETURN d;
END CreateDictionary;

PROCEDURE DictionaryAt*(d: Dictionary; key: Object): Object;
BEGIN
  HALT(99); (* Not fully implemented *)
  RETURN NIL
END DictionaryAt;

PROCEDURE DictionaryAtPut*(d: Dictionary; key, value: Object);
BEGIN
  HALT(99); (* Not fully implemented *)
END DictionaryAtPut;

END SOM.

