(* Copyright (c) 2026 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
 *
 * This benchmark is derived from Mario Wolczko's Java and Smalltalk version of
 * DeltaBlue.
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

MODULE DeltaBlue;

IMPORT SOM, Benchmark;

CONST
  FORWARD = 1; BACKWARD = 2;

TYPE
  INT32 = SOM.INT32;

  DeltaBlue* = POINTER TO DeltaBlueDesc;
  DeltaBlueDesc* = RECORD (Benchmark.BenchmarkDesc) END;

  Sym = POINTER TO SymDesc;
  SymDesc = RECORD (SOM.ObjectDesc) hash: INT32 END;

  Strength = POINTER TO StrengthDesc;
  StrengthDesc = RECORD (SOM.ObjectDesc)
    arithmeticValue: INT32;
    symbolicValue: Sym;
  END;

  Variable = POINTER TO VariableDesc;
  AbstractConstraint = POINTER TO AbstractConstraintDesc;

  VariableDesc = RECORD (SOM.ObjectDesc)
    value: INT32;
    constraints: SOM.Vector;
    determinedBy: AbstractConstraint;
    mark: INT32;
    walkStrength: Strength;
    stay: BOOLEAN;
  END;

  AbstractConstraintDesc = RECORD (SOM.ObjectDesc)
    strength: Strength;
  END;

  UnaryConstraint = POINTER TO UnaryConstraintDesc;
  UnaryConstraintDesc = RECORD (AbstractConstraintDesc)
    output: Variable;
    satisfied: BOOLEAN;
  END;

  EditConstraint = POINTER TO EditConstraintDesc;
  EditConstraintDesc = RECORD (UnaryConstraintDesc) END;

  StayConstraint = POINTER TO StayConstraintDesc;
  StayConstraintDesc = RECORD (UnaryConstraintDesc) END;

  BinaryConstraint = POINTER TO BinaryConstraintDesc;
  BinaryConstraintDesc = RECORD (AbstractConstraintDesc)
    v1, v2: Variable;
    direction: INT32;
  END;

  EqualityConstraint = POINTER TO EqualityConstraintDesc;
  EqualityConstraintDesc = RECORD (BinaryConstraintDesc) END;

  ScaleConstraint = POINTER TO ScaleConstraintDesc;
  ScaleConstraintDesc = RECORD (BinaryConstraintDesc)
    scale, offset: Variable;
  END;

  Plan = POINTER TO PlanDesc;
  PlanDesc = RECORD (SOM.ObjectDesc)
    constraints: SOM.Vector;
  END;

  Planner = POINTER TO PlannerDesc;
  PlannerDesc = RECORD (SOM.ObjectDesc)
    currentMark: INT32;
  END;

  VarIterator = PROCEDURE(v: Variable; data: SOM.Object);
  VarTester = PROCEDURE(v: Variable; data: SOM.Object): BOOLEAN;

VAR
  ABSOLUTESTRONGEST, REQUIREDSYM, STRONGPREFERRED, PREFERREDSYM: Sym;
  STRONGDEFAULT, DEFAULTSYM, WEAKDEFAULT, ABSOLUTEWEAKEST: Sym;
  strengthTable: SOM.Dictionary;
  strengthConstant: SOM.Dictionary;
  absoluteWeakest, required: Strength;

(* --- Sym --- *)

PROCEDURE CreateSym(hash: INT32): Sym;
  VAR s: Sym;
BEGIN
  NEW(s); s.hash := hash; RETURN s
END CreateSym;

PROCEDURE SymHash(obj: SOM.Object): INT32;
BEGIN
  RETURN obj(Sym).hash
END SymHash;

(* --- Strength --- *)

PROCEDURE StrengthOf(sym: Sym): Strength;
BEGIN
  RETURN SOM.DictionaryAt(strengthConstant, sym)(Strength)
END StrengthOf;

PROCEDURE StrengthSameAs(a, b: Strength): BOOLEAN;
BEGIN
  RETURN a.arithmeticValue = b.arithmeticValue
END StrengthSameAs;

PROCEDURE StrengthStronger(a, b: Strength): BOOLEAN;
BEGIN
  RETURN a.arithmeticValue < b.arithmeticValue
END StrengthStronger;

PROCEDURE StrengthWeaker(a, b: Strength): BOOLEAN;
BEGIN
  RETURN a.arithmeticValue > b.arithmeticValue
END StrengthWeaker;

PROCEDURE StrengthStrongest(a, b: Strength): Strength;
BEGIN
  IF StrengthStronger(b, a) THEN RETURN b ELSE RETURN a END
END StrengthStrongest;

PROCEDURE StrengthWeakest(a, b: Strength): Strength;
BEGIN
  IF StrengthWeaker(b, a) THEN RETURN b ELSE RETURN a END
END StrengthWeakest;

PROCEDURE CreateStrength(sym: Sym): Strength;
  VAR s: Strength;
BEGIN
  NEW(s);
  s.symbolicValue := sym;
  s.arithmeticValue := SOM.DictionaryAt(strengthTable, sym)(SOM.IntObject).value;
  RETURN s
END CreateStrength;

PROCEDURE StrengthInit;
  VAR keys: SOM.Vector; i: INT32; key: Sym; str: Strength;
BEGIN
  IF ABSOLUTESTRONGEST # NIL THEN RETURN END;
  ABSOLUTESTRONGEST := CreateSym(0);
  REQUIREDSYM       := CreateSym(1);
  STRONGPREFERRED   := CreateSym(2);
  PREFERREDSYM      := CreateSym(3);
  STRONGDEFAULT     := CreateSym(4);
  DEFAULTSYM        := CreateSym(5);
  WEAKDEFAULT       := CreateSym(6);
  ABSOLUTEWEAKEST   := CreateSym(7);

  strengthTable := SOM.CreateDictionary(SymHash);
  SOM.DictionaryAtPut(strengthTable, ABSOLUTESTRONGEST, SOM.CreateIntObject(-10000));
  SOM.DictionaryAtPut(strengthTable, REQUIREDSYM,       SOM.CreateIntObject(-800));
  SOM.DictionaryAtPut(strengthTable, STRONGPREFERRED,   SOM.CreateIntObject(-600));
  SOM.DictionaryAtPut(strengthTable, PREFERREDSYM,      SOM.CreateIntObject(-400));
  SOM.DictionaryAtPut(strengthTable, STRONGDEFAULT,     SOM.CreateIntObject(-200));
  SOM.DictionaryAtPut(strengthTable, DEFAULTSYM,        SOM.CreateIntObject(0));
  SOM.DictionaryAtPut(strengthTable, WEAKDEFAULT,       SOM.CreateIntObject(500));
  SOM.DictionaryAtPut(strengthTable, ABSOLUTEWEAKEST,   SOM.CreateIntObject(10000));

  strengthConstant := SOM.CreateDictionary(SymHash);
  keys := SOM.CreateVector(0);
  SOM.DictionaryGetKeys(strengthTable, keys);
  FOR i := 0 TO SOM.VectorSize(keys) - 1 DO
    key := SOM.VectorAt(keys, i)(Sym);
    str := CreateStrength(key);
    SOM.DictionaryAtPut(strengthConstant, key, str);
  END;

  absoluteWeakest := StrengthOf(ABSOLUTEWEAKEST);
  required        := StrengthOf(REQUIREDSYM);
END StrengthInit;

PROCEDURE StrengthDeinit;
BEGIN
  ABSOLUTESTRONGEST := NIL;
  REQUIREDSYM := NIL;
  STRONGPREFERRED := NIL;
  PREFERREDSYM := NIL;
  STRONGDEFAULT := NIL;
  DEFAULTSYM := NIL;
  WEAKDEFAULT := NIL;
  ABSOLUTEWEAKEST := NIL;
  strengthTable := NIL;
  strengthConstant := NIL;
  absoluteWeakest := NIL;
  required := NIL;
END StrengthDeinit;

(* --- Variable --- *)

PROCEDURE CreateVariable(): Variable;
  VAR v: Variable;
BEGIN
  NEW(v);
  v.value := 0;
  v.constraints := SOM.CreateVector(2);
  v.determinedBy := NIL;
  v.walkStrength := absoluteWeakest;
  v.stay := TRUE;
  v.mark := 0;
  RETURN v
END CreateVariable;

PROCEDURE CreateVariableValue(aValue: INT32): Variable;
  VAR v: Variable;
BEGIN
  v := CreateVariable();
  v.value := aValue;
  RETURN v
END CreateVariableValue;

(* --- Plan --- *)

PROCEDURE CreatePlan(): Plan;
  VAR p: Plan;
BEGIN
  NEW(p); p.constraints := SOM.CreateVector(15); RETURN p
END CreatePlan;

PROCEDURE PlanExecute(p: Plan);
  VAR i: INT32; c: AbstractConstraint;
BEGIN
  FOR i := 0 TO SOM.VectorSize(p.constraints) - 1 DO
    c := SOM.VectorAt(p.constraints, i)(AbstractConstraint);
    (* inline execute dispatch *)
    IF c IS ScaleConstraint THEN
      IF c(ScaleConstraint).direction = FORWARD THEN
        c(ScaleConstraint).v2.value :=
          c(ScaleConstraint).v1.value * c(ScaleConstraint).scale.value + c(ScaleConstraint).offset.value
      ELSE
        c(ScaleConstraint).v1.value :=
          (c(ScaleConstraint).v2.value - c(ScaleConstraint).offset.value) DIV c(ScaleConstraint).scale.value
      END;
    ELSIF c IS EqualityConstraint THEN
      IF c(EqualityConstraint).direction = FORWARD THEN
        c(EqualityConstraint).v2.value := c(EqualityConstraint).v1.value
      ELSE
        c(EqualityConstraint).v1.value := c(EqualityConstraint).v2.value
      END;
    END;
  END;
END PlanExecute;

(* --- Constraint Dispatch Functions --- *)

PROCEDURE ConstraintIsInput(c: AbstractConstraint): BOOLEAN;
BEGIN
  IF c IS EditConstraint THEN RETURN TRUE END;
  RETURN FALSE
END ConstraintIsInput;

PROCEDURE ConstraintIsSatisfied(c: AbstractConstraint): BOOLEAN;
BEGIN
  IF c IS UnaryConstraint THEN RETURN c(UnaryConstraint).satisfied
  ELSIF c IS BinaryConstraint THEN RETURN c(BinaryConstraint).direction # 0
  END;
  RETURN FALSE
END ConstraintIsSatisfied;

PROCEDURE ConstraintExecute(c: AbstractConstraint);
BEGIN
  IF c IS ScaleConstraint THEN
    IF c(ScaleConstraint).direction = FORWARD THEN
      c(ScaleConstraint).v2.value :=
        c(ScaleConstraint).v1.value * c(ScaleConstraint).scale.value + c(ScaleConstraint).offset.value
    ELSE
      c(ScaleConstraint).v1.value :=
        (c(ScaleConstraint).v2.value - c(ScaleConstraint).offset.value) DIV c(ScaleConstraint).scale.value
    END;
  ELSIF c IS EqualityConstraint THEN
    IF c(EqualityConstraint).direction = FORWARD THEN
      c(EqualityConstraint).v2.value := c(EqualityConstraint).v1.value
    ELSE
      c(EqualityConstraint).v1.value := c(EqualityConstraint).v2.value
    END;
  END;
END ConstraintExecute;

PROCEDURE ConstraintAddToGraph(c: AbstractConstraint);
BEGIN
  IF c IS ScaleConstraint THEN
    SOM.VectorAppend(c(ScaleConstraint).v1.constraints, c);
    SOM.VectorAppend(c(ScaleConstraint).v2.constraints, c);
    SOM.VectorAppend(c(ScaleConstraint).scale.constraints, c);
    SOM.VectorAppend(c(ScaleConstraint).offset.constraints, c);
    c(ScaleConstraint).direction := 0;
  ELSIF c IS BinaryConstraint THEN
    SOM.VectorAppend(c(BinaryConstraint).v1.constraints, c);
    SOM.VectorAppend(c(BinaryConstraint).v2.constraints, c);
    c(BinaryConstraint).direction := 0;
  ELSIF c IS UnaryConstraint THEN
    SOM.VectorAppend(c(UnaryConstraint).output.constraints, c);
    c(UnaryConstraint).satisfied := FALSE;
  END;
END ConstraintAddToGraph;

PROCEDURE ConstraintRemoveFromGraph(c: AbstractConstraint);
BEGIN
  IF c IS ScaleConstraint THEN
    IF c(ScaleConstraint).v1 # NIL THEN SOM.VectorRemove(c(ScaleConstraint).v1.constraints, c) END;
    IF c(ScaleConstraint).v2 # NIL THEN SOM.VectorRemove(c(ScaleConstraint).v2.constraints, c) END;
    IF c(ScaleConstraint).scale # NIL THEN SOM.VectorRemove(c(ScaleConstraint).scale.constraints, c) END;
    IF c(ScaleConstraint).offset # NIL THEN SOM.VectorRemove(c(ScaleConstraint).offset.constraints, c) END;
    c(ScaleConstraint).direction := 0;
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).v1 # NIL THEN SOM.VectorRemove(c(BinaryConstraint).v1.constraints, c) END;
    IF c(BinaryConstraint).v2 # NIL THEN SOM.VectorRemove(c(BinaryConstraint).v2.constraints, c) END;
    c(BinaryConstraint).direction := 0;
  ELSIF c IS UnaryConstraint THEN
    IF c(UnaryConstraint).output # NIL THEN SOM.VectorRemove(c(UnaryConstraint).output.constraints, c) END;
    c(UnaryConstraint).satisfied := FALSE;
  END;
END ConstraintRemoveFromGraph;

PROCEDURE ConstraintChooseMethod(c: AbstractConstraint; mark: INT32): INT32;
BEGIN
  IF c IS UnaryConstraint THEN
    c(UnaryConstraint).satisfied :=
      (c(UnaryConstraint).output.mark # mark) &
      StrengthStronger(c.strength, c(UnaryConstraint).output.walkStrength);
    RETURN 0;
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).v1.mark = mark THEN
      IF (c(BinaryConstraint).v2.mark # mark) &
         StrengthStronger(c.strength, c(BinaryConstraint).v2.walkStrength) THEN
        c(BinaryConstraint).direction := FORWARD;
      ELSE
        c(BinaryConstraint).direction := 0;
      END;
    ELSIF c(BinaryConstraint).v2.mark = mark THEN
      IF (c(BinaryConstraint).v1.mark # mark) &
         StrengthStronger(c.strength, c(BinaryConstraint).v1.walkStrength) THEN
        c(BinaryConstraint).direction := BACKWARD;
      ELSE
        c(BinaryConstraint).direction := 0;
      END;
    ELSE
      IF StrengthWeaker(c(BinaryConstraint).v1.walkStrength, c(BinaryConstraint).v2.walkStrength) THEN
        IF StrengthStronger(c.strength, c(BinaryConstraint).v1.walkStrength) THEN
          c(BinaryConstraint).direction := BACKWARD;
        ELSE
          c(BinaryConstraint).direction := 0;
        END;
      ELSE
        IF StrengthStronger(c.strength, c(BinaryConstraint).v2.walkStrength) THEN
          c(BinaryConstraint).direction := FORWARD;
        ELSE
          c(BinaryConstraint).direction := 0;
        END;
      END;
    END;
    RETURN c(BinaryConstraint).direction;
  END;
  RETURN 0
END ConstraintChooseMethod;

PROCEDURE ConstraintInputsDo(c: AbstractConstraint; fn: VarIterator; data: SOM.Object);
BEGIN
  IF c IS ScaleConstraint THEN
    IF c(ScaleConstraint).direction = FORWARD THEN
      fn(c(ScaleConstraint).v1, data);
      fn(c(ScaleConstraint).scale, data);
      fn(c(ScaleConstraint).offset, data);
    ELSE
      fn(c(ScaleConstraint).v2, data);
      fn(c(ScaleConstraint).scale, data);
      fn(c(ScaleConstraint).offset, data);
    END;
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).direction = FORWARD THEN
      fn(c(BinaryConstraint).v1, data);
    ELSE
      fn(c(BinaryConstraint).v2, data);
    END;
  END;
END ConstraintInputsDo;

PROCEDURE ConstraintInputsHasOne(c: AbstractConstraint; fn: VarTester; data: SOM.Object): BOOLEAN;
BEGIN
  IF c IS UnaryConstraint THEN RETURN FALSE
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).direction = FORWARD THEN
      RETURN fn(c(BinaryConstraint).v1, data)
    ELSE
      RETURN fn(c(BinaryConstraint).v2, data)
    END;
  END;
  RETURN FALSE
END ConstraintInputsHasOne;

PROCEDURE ConstraintMarkUnsatisfied(c: AbstractConstraint);
BEGIN
  IF c IS UnaryConstraint THEN c(UnaryConstraint).satisfied := FALSE
  ELSIF c IS BinaryConstraint THEN c(BinaryConstraint).direction := 0
  END;
END ConstraintMarkUnsatisfied;

PROCEDURE ConstraintGetOutput(c: AbstractConstraint): Variable;
BEGIN
  IF c IS UnaryConstraint THEN RETURN c(UnaryConstraint).output
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).direction = FORWARD THEN
      RETURN c(BinaryConstraint).v2
    ELSE
      RETURN c(BinaryConstraint).v1
    END;
  END;
  RETURN NIL
END ConstraintGetOutput;

PROCEDURE ConstraintRecalculate(c: AbstractConstraint);
  VAR inp, out: Variable;
BEGIN
  IF c IS ScaleConstraint THEN
    IF c(ScaleConstraint).direction = FORWARD THEN
      inp := c(ScaleConstraint).v1; out := c(ScaleConstraint).v2;
    ELSE
      out := c(ScaleConstraint).v1; inp := c(ScaleConstraint).v2;
    END;
    out.walkStrength := StrengthWeakest(c.strength, inp.walkStrength);
    out.stay := inp.stay & c(ScaleConstraint).scale.stay & c(ScaleConstraint).offset.stay;
    IF out.stay THEN ConstraintExecute(c) END;
  ELSIF c IS BinaryConstraint THEN
    IF c(BinaryConstraint).direction = FORWARD THEN
      inp := c(BinaryConstraint).v1; out := c(BinaryConstraint).v2;
    ELSE
      inp := c(BinaryConstraint).v2; out := c(BinaryConstraint).v1;
    END;
    out.walkStrength := StrengthWeakest(c.strength, inp.walkStrength);
    out.stay := inp.stay;
    IF out.stay THEN ConstraintExecute(c) END;
  ELSIF c IS UnaryConstraint THEN
    out := c(UnaryConstraint).output;
    out.walkStrength := c.strength;
    out.stay := ~ConstraintIsInput(c);
    IF out.stay THEN ConstraintExecute(c) END;
  END;
END ConstraintRecalculate;

(* --- InputsKnown --- *)

PROCEDURE InputsKnownTester(v: Variable; data: SOM.Object): BOOLEAN;
  VAR mark: INT32;
BEGIN
  mark := data(SOM.IntObject).value;
  RETURN ~((v.mark = mark) OR v.stay OR (v.determinedBy = NIL))
END InputsKnownTester;

PROCEDURE InputsKnown(c: AbstractConstraint; mark: INT32): BOOLEAN;
BEGIN
  RETURN ~ConstraintInputsHasOne(c, InputsKnownTester, SOM.CreateIntObject(mark))
END InputsKnown;

(* --- Planner helpers --- *)

PROCEDURE NewMark(planner: Planner): INT32;
BEGIN
  INC(planner.currentMark);
  RETURN planner.currentMark
END NewMark;

PROCEDURE AddConstraintsConsumingTo(v: Variable; coll: SOM.Vector);
  VAR i: INT32; c: AbstractConstraint;
BEGIN
  FOR i := 0 TO SOM.VectorSize(v.constraints) - 1 DO
    c := SOM.VectorAt(v.constraints, i)(AbstractConstraint);
    IF (c # v.determinedBy) & ConstraintIsSatisfied(c) THEN
      SOM.VectorAppend(coll, c);
    END;
  END;
END AddConstraintsConsumingTo;

PROCEDURE StrengthCompare(a, b: SOM.Object): INTEGER;
BEGIN
  IF StrengthStronger(a(AbstractConstraint).strength, b(AbstractConstraint).strength) THEN
    RETURN -1
  ELSE
    RETURN 1
  END
END StrengthCompare;

(* --- Planner core --- *)

PROCEDURE RemovePropagateFrom(planner: Planner; out: Variable; unsatisfied: SOM.Vector);
  VAR todo: SOM.Vector; v: Variable; i: INT32;
      c, determiningC: AbstractConstraint; outVar: Variable;
BEGIN
  out.determinedBy := NIL;
  out.walkStrength := absoluteWeakest;
  out.stay := TRUE;
  todo := SOM.CreateVector(0);
  SOM.VectorAppend(todo, out);
  WHILE ~SOM.VectorIsEmpty(todo) DO
    v := SOM.VectorRemoveFirst(todo)(Variable);
    FOR i := 0 TO SOM.VectorSize(v.constraints) - 1 DO
      c := SOM.VectorAt(v.constraints, i)(AbstractConstraint);
      IF ~ConstraintIsSatisfied(c) THEN SOM.VectorAppend(unsatisfied, c) END;
    END;
    determiningC := v.determinedBy;
    FOR i := 0 TO SOM.VectorSize(v.constraints) - 1 DO
      c := SOM.VectorAt(v.constraints, i)(AbstractConstraint);
      IF (c # determiningC) & ConstraintIsSatisfied(c) THEN
        ConstraintRecalculate(c);
        outVar := ConstraintGetOutput(c);
        SOM.VectorAppend(todo, outVar);
      END;
    END;
  END;
  SOM.VectorSort(unsatisfied, StrengthCompare);
END RemovePropagateFrom;

PROCEDURE AddPropagate(planner: Planner; c: AbstractConstraint; mark: INT32): BOOLEAN;
  VAR todo: SOM.Vector; d: AbstractConstraint;
BEGIN
  todo := SOM.CreateVector(0);
  SOM.VectorAppend(todo, c);
  WHILE ~SOM.VectorIsEmpty(todo) DO
    d := SOM.VectorRemoveFirst(todo)(AbstractConstraint);
    IF ConstraintGetOutput(d).mark = mark THEN
      IncrementalRemove(planner, c);
      RETURN FALSE
    END;
    ConstraintRecalculate(d);
    AddConstraintsConsumingTo(ConstraintGetOutput(d), todo);
  END;
  RETURN TRUE
END AddPropagate;

PROCEDURE SatisfyIter(v: Variable; data: SOM.Object);
BEGIN
  v.mark := data(SOM.IntObject).value;
END SatisfyIter;

PROCEDURE Satisfy(c: AbstractConstraint; mark: INT32; planner: Planner): AbstractConstraint;
  VAR overridden: AbstractConstraint; out: Variable;
BEGIN
  ConstraintChooseMethod(c, mark);
  IF ConstraintIsSatisfied(c) THEN
    ConstraintInputsDo(c, SatisfyIter, SOM.CreateIntObject(mark));
    out := ConstraintGetOutput(c);
    overridden := out.determinedBy;
    IF overridden # NIL THEN ConstraintMarkUnsatisfied(overridden) END;
    out.determinedBy := c;
    IF ~AddPropagate(planner, c, mark) THEN HALT(99) END;
    out.mark := mark;
  ELSE
    overridden := NIL;
    IF StrengthSameAs(c.strength, required) THEN HALT(99) END;
  END;
  RETURN overridden
END Satisfy;

PROCEDURE IncrementalAdd(planner: Planner; c: AbstractConstraint);
  VAR mark: INT32; overridden: AbstractConstraint;
BEGIN
  mark := NewMark(planner);
  overridden := Satisfy(c, mark, planner);
  WHILE overridden # NIL DO
    overridden := Satisfy(overridden, mark, planner);
  END;
END IncrementalAdd;

PROCEDURE IncrementalRemove(planner: Planner; c: AbstractConstraint);
  VAR out: Variable; unsatisfied: SOM.Vector; i: INT32;
BEGIN
  out := ConstraintGetOutput(c);
  ConstraintMarkUnsatisfied(c);
  ConstraintRemoveFromGraph(c);
  unsatisfied := SOM.CreateVector(0);
  RemovePropagateFrom(planner, out, unsatisfied);
  FOR i := 0 TO SOM.VectorSize(unsatisfied) - 1 DO
    IncrementalAdd(planner, SOM.VectorAt(unsatisfied, i)(AbstractConstraint));
  END;
END IncrementalRemove;

PROCEDURE AddConstraint(c: AbstractConstraint; planner: Planner);
BEGIN
  ConstraintAddToGraph(c);
  IncrementalAdd(planner, c);
END AddConstraint;

PROCEDURE DestroyConstraint(c: AbstractConstraint; planner: Planner);
BEGIN
  IF ConstraintIsSatisfied(c) THEN IncrementalRemove(planner, c) END;
  ConstraintRemoveFromGraph(c);
END DestroyConstraint;

PROCEDURE MakePlan(planner: Planner; sources: SOM.Vector): Plan;
  VAR mark: INT32; plan: Plan; todo: SOM.Vector;
      c: AbstractConstraint; outVar: Variable;
BEGIN
  mark := NewMark(planner);
  plan := CreatePlan();
  todo := SOM.VectorCopy(sources);
  WHILE ~SOM.VectorIsEmpty(todo) DO
    c := SOM.VectorRemoveFirst(todo)(AbstractConstraint);
    outVar := ConstraintGetOutput(c);
    IF (outVar.mark # mark) & InputsKnown(c, mark) THEN
      SOM.VectorAppend(plan.constraints, c);
      outVar.mark := mark;
      AddConstraintsConsumingTo(outVar, todo);
    END;
  END;
  RETURN plan
END MakePlan;

PROCEDURE ExtractPlanFromConstraints(planner: Planner; constraints: SOM.Vector): Plan;
  VAR sources: SOM.Vector; i: INT32; c: AbstractConstraint;
BEGIN
  sources := SOM.CreateVector(0);
  FOR i := 0 TO SOM.VectorSize(constraints) - 1 DO
    c := SOM.VectorAt(constraints, i)(AbstractConstraint);
    IF ConstraintIsInput(c) & ConstraintIsSatisfied(c) THEN
      SOM.VectorAppend(sources, c);
    END;
  END;
  RETURN MakePlan(planner, sources)
END ExtractPlanFromConstraints;

(* --- Constraint Constructors --- *)

PROCEDURE CreateEditConstraint(v: Variable; strength: Sym; planner: Planner): EditConstraint;
  VAR c: EditConstraint;
BEGIN
  NEW(c);
  c.strength := StrengthOf(strength);
  c.output := v; c.satisfied := FALSE;
  AddConstraint(c, planner);
  RETURN c
END CreateEditConstraint;

PROCEDURE CreateStayConstraint(v: Variable; strength: Sym; planner: Planner): StayConstraint;
  VAR c: StayConstraint;
BEGIN
  NEW(c);
  c.strength := StrengthOf(strength);
  c.output := v; c.satisfied := FALSE;
  AddConstraint(c, planner);
  RETURN c
END CreateStayConstraint;

PROCEDURE CreateEqualityConstraint(var1, var2: Variable; strength: Sym; planner: Planner): EqualityConstraint;
  VAR c: EqualityConstraint;
BEGIN
  NEW(c);
  c.strength := StrengthOf(strength);
  c.v1 := var1; c.v2 := var2; c.direction := 0;
  AddConstraint(c, planner);
  RETURN c
END CreateEqualityConstraint;

PROCEDURE CreateScaleConstraint(src, scale, offset, dest: Variable; strength: Sym; planner: Planner): ScaleConstraint;
  VAR c: ScaleConstraint;
BEGIN
  NEW(c);
  c.strength := StrengthOf(strength);
  c.v1 := src; c.v2 := dest; c.direction := 0;
  c.scale := scale; c.offset := offset;
  AddConstraint(c, planner);
  RETURN c
END CreateScaleConstraint;

(* --- Change, ChainTest, ProjectionTest --- *)

PROCEDURE Change(planner: Planner; v: Variable; newValue: INT32);
  VAR editC: EditConstraint; editV: SOM.Vector; plan: Plan; i: INT32;
BEGIN
  editC := CreateEditConstraint(v, PREFERREDSYM, planner);
  editV := SOM.CreateVector(0);
  SOM.VectorAppend(editV, editC);
  plan := ExtractPlanFromConstraints(planner, editV);
  FOR i := 0 TO 9 DO
    v.value := newValue;
    PlanExecute(plan);
  END;
  DestroyConstraint(editC, planner);
END Change;

PROCEDURE ChainTest(n: INT32);
  VAR planner: Planner; vars: SOM.Vector; i: INT32;
      v1, v2: Variable;
      editC: EditConstraint; plan: Plan;
      editV: SOM.Vector;
      tmp: AbstractConstraint;
BEGIN
  NEW(planner); planner.currentMark := 1;
  vars := SOM.CreateVector(n + 1);
  FOR i := 0 TO n DO
    SOM.VectorAtPut(vars, i, CreateVariable());
  END;

  FOR i := 0 TO n - 1 DO
    v1 := SOM.VectorAt(vars, i)(Variable);
    v2 := SOM.VectorAt(vars, i + 1)(Variable);
    tmp := CreateEqualityConstraint(v1, v2, REQUIREDSYM, planner);
  END;

  tmp := CreateStayConstraint(SOM.VectorAt(vars, n)(Variable), STRONGDEFAULT, planner);
  editC := CreateEditConstraint(SOM.VectorAt(vars, 0)(Variable), PREFERREDSYM, planner);
  editV := SOM.CreateVector(0);
  SOM.VectorAppend(editV, editC);
  plan := ExtractPlanFromConstraints(planner, editV);
  FOR i := 0 TO 99 DO
    SOM.VectorAt(vars, 0)(Variable).value := i;
    PlanExecute(plan);
    IF SOM.VectorAt(vars, n)(Variable).value # i THEN HALT(99) END;
  END;
  DestroyConstraint(editC, planner);
END ChainTest;

PROCEDURE ProjectionTest(n: INT32);
  VAR planner: Planner;
      scale, offset, src, dst: Variable;
      dests: SOM.Vector;
      i: INT32; tmp: AbstractConstraint; v: Variable;
BEGIN
  NEW(planner); planner.currentMark := 1;
  scale := CreateVariableValue(10);
  offset := CreateVariableValue(1000);
  dests := SOM.CreateVector(0);

  src := NIL; dst := NIL;
  FOR i := 1 TO n DO
    src := CreateVariableValue(i);
    dst := CreateVariableValue(i);
    SOM.VectorAppend(dests, dst);
    tmp := CreateStayConstraint(src, DEFAULTSYM, planner);
    tmp := CreateScaleConstraint(src, scale, offset, dst, REQUIREDSYM, planner);
  END;

  Change(planner, src, 17);
  IF dst.value # 1170 THEN HALT(99) END;

  Change(planner, dst, 1050);
  IF src.value # 5 THEN HALT(99) END;

  Change(planner, scale, 5);
  FOR i := 0 TO n - 2 DO
    v := SOM.VectorAt(dests, i)(Variable);
    IF v.value # (i + 1) * 5 + 1000 THEN HALT(99) END;
  END;

  Change(planner, offset, 2000);
  FOR i := 0 TO n - 2 DO
    v := SOM.VectorAt(dests, i)(Variable);
    IF v.value # (i + 1) * 5 + 2000 THEN HALT(99) END;
  END;
END ProjectionTest;

(* --- Benchmark Interface --- *)

PROCEDURE InnerBenchmarkLoop*(b: Benchmark.Benchmark; innerIterations: INTEGER): BOOLEAN;
BEGIN
  StrengthInit;
  ChainTest(innerIterations);
  ProjectionTest(innerIterations);
  StrengthDeinit;
  RETURN TRUE
END InnerBenchmarkLoop;

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
BEGIN
  HALT(99); RETURN NIL
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  HALT(99); RETURN FALSE
END VerifyResult;

PROCEDURE Create*(): DeltaBlue;
  VAR d: DeltaBlue;
BEGIN
  NEW(d);
  d.InnerBenchmarkLoop := InnerBenchmarkLoop;
  d.DoBenchmark := DoBenchmark;
  d.VerifyResult := VerifyResult;
  RETURN d
END Create;

END DeltaBlue.
