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
  INITIALVECTORSIZE* = 50;
  INITIALSETSIZE*    = 10;
  INITIALCAPACITY*    = 16;

TYPE
  INT32* = LONGINT;
  F64* = LONGREAL;

  Object* = POINTER TO ObjectDesc;
  ObjectDesc* = RECORD END;

  ValueIterator* = PROCEDURE (item: Object; data: Object);
  TestIterator*  = PROCEDURE (item: Object; data: Object): BOOLEAN;
  Compare*       = PROCEDURE (a, b: Object): INTEGER;

  IntObject* = POINTER TO IntObjectDesc;
  IntObjectDesc* = RECORD (ObjectDesc) value*: INT32 END;

  BoolObject* = POINTER TO BoolObjectDesc;
  BoolObjectDesc* = RECORD (ObjectDesc) value*: BOOLEAN END;

  Vector*     = POINTER TO VectorDesc;
  Set*        = POINTER TO SetDesc;
  Dictionary* = POINTER TO DictionaryDesc;
  Storage* = POINTER TO ARRAY OF Object;

  VectorDesc* = RECORD (ObjectDesc)
    storage: Storage;
    firstIdx, lastIdx: INT32;
  END;

  SetDesc* = RECORD (ObjectDesc)
    items*: Vector;
  END;

  SetContainsContext = POINTER TO SetContainsContextDesc;
  SetContainsContextDesc = RECORD (ObjectDesc)
    objToFind: Object;
    found: BOOLEAN;
  END;

  Entry = POINTER TO EntryDesc;
  EntryDesc = RECORD (ObjectDesc)
    hash: INT32;
    key, value: Object;
    next: Entry;
  END;

  HashProc* = PROCEDURE (obj: Object): INT32;

  Buckets = POINTER TO ARRAY OF Entry;
  
  DictionaryDesc* = RECORD (ObjectDesc)
    buckets: Buckets;
    size*: INT32;
    hashFunc: HashProc;
  END;

  IntStorage* = POINTER TO ARRAY OF INT32;
  IntVector* = POINTER TO IntVectorDesc;
  IntVectorDesc* = RECORD (ObjectDesc)
    storage: IntStorage;
    firstIdx, lastIdx: INT32;
  END;

  IntSet* = POINTER TO IntSetDesc;
  IntSetDesc* = RECORD (ObjectDesc)
    items*: IntVector;
  END;

  IntValueIterator* = PROCEDURE (item: INT32; data: Object);
  IntTestIterator*  = PROCEDURE (item: INT32; data: Object): BOOLEAN;

(* --- Wrapper Constructors --- *)

PROCEDURE CreateIntObject*(v: INT32): IntObject;
  VAR o: IntObject;
BEGIN
  NEW(o); o.value := v; RETURN o
END CreateIntObject;

PROCEDURE CreateBoolObject*(v: BOOLEAN): BoolObject;
  VAR o: BoolObject;
BEGIN
  NEW(o); o.value := v; RETURN o
END CreateBoolObject;

(* --- Default Equality and Hashing --- *)

PROCEDURE ObjectsEqual*(a, b: Object): BOOLEAN;
BEGIN
  RETURN a = b;
END ObjectsEqual;

PROCEDURE DefaultHash*(obj: Object): INT32;
  VAR h: INT32;
BEGIN
  h := SYSTEM.VAL(INT32, obj);
  RETURN SYSTEM.VAL(INT32, SYSTEM.VAL(SET, h) / SYSTEM.VAL(SET, SYSTEM.LSH(h, -16)));
END DefaultHash;

(* --- Private Iterator for Set.Contains --- *)

PROCEDURE SetContainsCheck(item: Object; data: Object): BOOLEAN;
  VAR context: SetContainsContext;
BEGIN
  context := data(SetContainsContext); 
  IF ObjectsEqual(item, context.objToFind) THEN
    context.found := TRUE;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END;
END SetContainsCheck;

(* --- Vector Procedures --- *)

PROCEDURE EnlargeVector(v: Vector; minSize: INT32);
  VAR newLength: INT32;
      newStorage: Storage;
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
  IF initialSize = 0 THEN size := INITIALVECTORSIZE ELSE size := initialSize END;
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
  VAR newStorage: Storage; i: INT32;
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

PROCEDURE VectorForEach*(v: Vector; p: ValueIterator; data: Object);
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    p(v.storage[i], data);
  END;
END VectorForEach;

PROCEDURE VectorHasSome*(v: Vector; p: TestIterator; data: Object): BOOLEAN;
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    IF p(v.storage[i], data) THEN RETURN TRUE END;
  END;
  RETURN FALSE;
END VectorHasSome;

PROCEDURE VectorRemove*(v: Vector; obj: Object): BOOLEAN;
  VAR
    newStorage: Storage;
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

PROCEDURE VectorRemoveFirst*(v: Vector): Object;
  VAR result: Object;
BEGIN
  IF v.firstIdx < v.lastIdx THEN
    result := v.storage[v.firstIdx];
    v.storage[v.firstIdx] := NIL;
    INC(v.firstIdx);
    RETURN result;
  END;
  RETURN NIL
END VectorRemoveFirst;

PROCEDURE VectorRemoveAll*(v: Vector);
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    v.storage[i] := NIL;
  END;
  v.firstIdx := 0;
  v.lastIdx := 0;
END VectorRemoveAll;

PROCEDURE VectorExpand*(v: Vector; newSize: INT32);
BEGIN
  IF newSize > LEN(v.storage^) THEN
    EnlargeVector(v, newSize - 1);
  END;
  IF v.lastIdx < newSize THEN
    v.lastIdx := newSize;
  END;
END VectorExpand;

PROCEDURE VectorCopy*(src: Vector): Vector;
  VAR dst: Vector; i: INT32;
BEGIN
  dst := CreateVector(VectorSize(src));
  FOR i := src.firstIdx TO src.lastIdx - 1 DO
    VectorAppend(dst, src.storage[i]);
  END;
  RETURN dst;
END VectorCopy;

PROCEDURE VectorSort*(v: Vector; cmp: Compare);
  VAR i, j: INT32; tmp: Object;
BEGIN
  i := v.firstIdx + 1;
  WHILE i < v.lastIdx DO
    tmp := v.storage[i];
    j := i;
    WHILE (j > v.firstIdx) & (cmp(v.storage[j - 1], tmp) > 0) DO
      v.storage[j] := v.storage[j - 1];
      DEC(j);
    END;
    v.storage[j] := tmp;
    INC(i);
  END;
END VectorSort;

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

PROCEDURE SetForEach*(s: Set; p: ValueIterator; data: Object);
BEGIN
  VectorForEach(s.items, p, data);
END SetForEach;

PROCEDURE SetHasSome*(s: Set; p: TestIterator; data: Object): BOOLEAN;
BEGIN
  RETURN VectorHasSome(s.items, p, data);
END SetHasSome;

PROCEDURE SetRemoveAll*(s: Set);
BEGIN
  VectorRemoveAll(s.items);
END SetRemoveAll;

(* --- Dictionary Procedures --- *)

PROCEDURE CreateDictionary*(hash: HashProc): Dictionary;
  VAR d: Dictionary; i: INT32;
BEGIN
  NEW(d);
  d.size := 0;
  d.hashFunc := hash;
  NEW(d.buckets, INITIALCAPACITY);
  FOR i := 0 TO INITIALCAPACITY - 1 DO
    d.buckets[i] := NIL;
  END;
  RETURN d;
END CreateDictionary;

PROCEDURE DictionaryBucketIdx(d: Dictionary; hash: INT32): INT32;
  VAR idx: INT32;
BEGIN
  idx := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, hash) * SYSTEM.VAL(SET, LEN(d.buckets^) - 1));
  IF idx < 0 THEN idx := -idx END;
  IF idx >= LEN(d.buckets^) THEN idx := idx MOD LEN(d.buckets^) END;
  RETURN idx
END DictionaryBucketIdx;

PROCEDURE DictionaryResize(d: Dictionary);
  VAR newCap, i, idx: INT32;
      newBuckets: Buckets;
      e, next: Entry;
BEGIN
  newCap := LEN(d.buckets^) * 2;
  NEW(newBuckets, newCap);
  FOR i := 0 TO newCap - 1 DO newBuckets[i] := NIL END;
  FOR i := 0 TO LEN(d.buckets^) - 1 DO
    e := d.buckets[i];
    WHILE e # NIL DO
      next := e.next;
      idx := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, e.hash) * SYSTEM.VAL(SET, newCap - 1));
      IF idx < 0 THEN idx := -idx END;
      IF idx >= newCap THEN idx := idx MOD newCap END;
      e.next := newBuckets[idx];
      newBuckets[idx] := e;
      e := next;
    END;
  END;
  d.buckets := newBuckets;
END DictionaryResize;

PROCEDURE DictionaryAt*(d: Dictionary; key: Object): Object;
  VAR hash, idx: INT32; e: Entry;
BEGIN
  hash := d.hashFunc(key);
  idx := DictionaryBucketIdx(d, hash);
  e := d.buckets[idx];
  WHILE e # NIL DO
    IF (e.hash = hash) & (e.key = key) THEN
      RETURN e.value;
    END;
    e := e.next;
  END;
  RETURN NIL
END DictionaryAt;

PROCEDURE DictionaryContainsKey*(d: Dictionary; key: Object): BOOLEAN;
  VAR hash, idx: INT32; e: Entry;
BEGIN
  hash := d.hashFunc(key);
  idx := DictionaryBucketIdx(d, hash);
  e := d.buckets[idx];
  WHILE e # NIL DO
    IF (e.hash = hash) & (e.key = key) THEN RETURN TRUE END;
    e := e.next;
  END;
  RETURN FALSE
END DictionaryContainsKey;

PROCEDURE DictionaryAtPut*(d: Dictionary; key, value: Object);
  VAR hash, idx: INT32; e: Entry;
BEGIN
  hash := d.hashFunc(key);
  idx := DictionaryBucketIdx(d, hash);
  e := d.buckets[idx];
  WHILE e # NIL DO
    IF (e.hash = hash) & (e.key = key) THEN
      e.value := value;
      RETURN;
    END;
    e := e.next;
  END;
  NEW(e);
  e.hash := hash;
  e.key := key;
  e.value := value;
  e.next := d.buckets[idx];
  d.buckets[idx] := e;
  INC(d.size);
  IF d.size > LEN(d.buckets^) THEN
    DictionaryResize(d);
  END;
END DictionaryAtPut;

PROCEDURE DictionaryRemoveAll*(d: Dictionary);
  VAR i: INT32;
BEGIN
  FOR i := 0 TO LEN(d.buckets^) - 1 DO
    d.buckets[i] := NIL;
  END;
  d.size := 0;
END DictionaryRemoveAll;

PROCEDURE DictionaryGetKeys*(d: Dictionary; keys: Vector);
  VAR i: INT32; e: Entry;
BEGIN
  FOR i := 0 TO LEN(d.buckets^) - 1 DO
    e := d.buckets[i];
    WHILE e # NIL DO
      VectorAppend(keys, e.key);
      e := e.next;
    END;
  END;
END DictionaryGetKeys;

PROCEDURE DictionaryGetValues*(d: Dictionary; values: Vector);
  VAR i: INT32; e: Entry;
BEGIN
  FOR i := 0 TO LEN(d.buckets^) - 1 DO
    e := d.buckets[i];
    WHILE e # NIL DO
      VectorAppend(values, e.value);
      e := e.next;
    END;
  END;
END DictionaryGetValues;

PROCEDURE DictionarySize*(d: Dictionary): INT32;
BEGIN
  RETURN d.size
END DictionarySize;

(* --- IntVector Procedures --- *)

PROCEDURE EnlargeIntVector(v: IntVector; minSize: INT32);
  VAR newLength: INT32;
      newStorage: IntStorage;
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
END EnlargeIntVector;

PROCEDURE CreateIntVector*(initialSize: INT32): IntVector;
  VAR v: IntVector; size: INT32;
BEGIN
  NEW(v);
  IF initialSize = 0 THEN size := INITIALVECTORSIZE ELSE size := initialSize END;
  NEW(v.storage, size);
  v.firstIdx := 0; v.lastIdx := 0;
  RETURN v;
END CreateIntVector;

PROCEDURE IntVectorAt*(v: IntVector; idx: INT32): INT32;
BEGIN
  RETURN v.storage[idx]
END IntVectorAt;

PROCEDURE IntVectorAtPut*(v: IntVector; idx: INT32; val: INT32);
BEGIN
  IF idx >= LEN(v.storage^) THEN
    EnlargeIntVector(v, idx);
  END;
  v.storage[idx] := val;
  IF v.lastIdx < idx + 1 THEN
    v.lastIdx := idx + 1;
  END;
END IntVectorAtPut;

PROCEDURE IntVectorAppend*(v: IntVector; elem: INT32);
  VAR newStorage: IntStorage; i: INT32;
BEGIN
  IF v.lastIdx >= LEN(v.storage^) THEN
    NEW(newStorage, LEN(v.storage^) * 2);
    FOR i := 0 TO LEN(v.storage^) - 1 DO newStorage[i] := v.storage[i] END;
    v.storage := newStorage;
  END;
  v.storage[v.lastIdx] := elem;
  INC(v.lastIdx);
END IntVectorAppend;

PROCEDURE IntVectorSize*(v: IntVector): INT32;
BEGIN
  RETURN v.lastIdx - v.firstIdx;
END IntVectorSize;

PROCEDURE IntVectorIsEmpty*(v: IntVector): BOOLEAN;
BEGIN
  RETURN v.lastIdx = v.firstIdx;
END IntVectorIsEmpty;

PROCEDURE IntVectorForEach*(v: IntVector; p: IntValueIterator; data: Object);
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    p(v.storage[i], data);
  END;
END IntVectorForEach;

PROCEDURE IntVectorHasSome*(v: IntVector; p: IntTestIterator; data: Object): BOOLEAN;
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    IF p(v.storage[i], data) THEN RETURN TRUE END;
  END;
  RETURN FALSE;
END IntVectorHasSome;

PROCEDURE IntVectorRemoveAll*(v: IntVector);
  VAR i: INT32;
BEGIN
  FOR i := v.firstIdx TO v.lastIdx - 1 DO
    v.storage[i] := 0;
  END;
  v.firstIdx := 0;
  v.lastIdx := 0;
END IntVectorRemoveAll;

PROCEDURE IntVectorExpand*(v: IntVector; newSize: INT32);
BEGIN
  IF newSize > LEN(v.storage^) THEN
    EnlargeIntVector(v, newSize - 1);
  END;
  IF v.lastIdx < newSize THEN
    v.lastIdx := newSize;
  END;
END IntVectorExpand;

(* --- IntSet Procedures --- *)

PROCEDURE CreateIntSet*(initialSize: INT32): IntSet;
  VAR s: IntSet;
BEGIN
  NEW(s);
  s.items := CreateIntVector(initialSize);
  RETURN s;
END CreateIntSet;

PROCEDURE IntSetSize*(s: IntSet): INT32;
BEGIN
  RETURN IntVectorSize(s.items);
END IntSetSize;

PROCEDURE IntSetContains*(s: IntSet; val: INT32): BOOLEAN;
  VAR i: INT32;
BEGIN
  FOR i := s.items.firstIdx TO s.items.lastIdx - 1 DO
    IF s.items.storage[i] = val THEN RETURN TRUE END;
  END;
  RETURN FALSE;
END IntSetContains;

PROCEDURE IntSetAdd*(s: IntSet; val: INT32);
BEGIN
  IF ~IntSetContains(s, val) THEN
    IntVectorAppend(s.items, val);
  END;
END IntSetAdd;

PROCEDURE IntSetForEach*(s: IntSet; p: IntValueIterator; data: Object);
BEGIN
  IntVectorForEach(s.items, p, data);
END IntSetForEach;

END SOM.
