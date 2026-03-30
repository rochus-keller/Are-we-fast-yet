MODULE MathL;
IMPORT SYSTEM;

CONST
  pi* = 3.14159265358979323846D0;
  e*  = 2.71828182845904523536D0;

(* x87 FPU Machine Code --- *)

PROCEDURE -Sin(x: LONGREAL): LONGREAL;
CODE {SYSTEM.i386, SYSTEM.FPU}
  DB 0DDH, 004H, 024H (* FLD qword [ESP] *)
  DB 0D9H, 0FEH       (* FSIN *)
  DB 058H             (* POP EAX *)
  DB 058H             (* POP EAX *)
END Sin;

PROCEDURE -Cos(x: LONGREAL): LONGREAL;
CODE {SYSTEM.i386, SYSTEM.FPU}
  DB 0DDH, 004H, 024H (* FLD qword [ESP] *)
  DB 0D9H, 0FFH       (* FCOS *)
  DB 058H             (* POP EAX *)
  DB 058H             (* POP EAX *)
END Cos;

PROCEDURE -Sqrt(x: LONGREAL): LONGREAL;
CODE {SYSTEM.i386, SYSTEM.FPU}
  DB 0DDH, 004H, 024H (* FLD qword [ESP] *)
  DB 0D9H, 0FAH       (* FSQRT ST(0) *)
  DB 058H             (* POP EAX *)
  DB 058H             (* POP EAX *)
END Sqrt;

(* Exported Procedures *)

PROCEDURE sin* (x: LONGREAL): LONGREAL;
BEGIN
  (* The x87 FSIN instruction operates correctly, but we mirror 
     ETH's bounds-check normalization for absolute equivalence. *)
  IF x < 0.0D0 THEN RETURN -Sin(-x) ELSE RETURN Sin(x) END 
END sin;

PROCEDURE cos* (x: LONGREAL): LONGREAL;
BEGIN 
  IF x < 0.0D0 THEN RETURN Cos(-x) ELSE RETURN Cos(x) END 
END cos;

PROCEDURE sqrt* (x: LONGREAL): LONGREAL;
BEGIN 
  IF x < 0.0D0 THEN 
    (* Domain error for negative square roots. Oberon usually 
       halts rather than propagating NaNs. *)
    HALT(80) 
  END;
  RETURN Sqrt(x)
END sqrt;

END MathL.