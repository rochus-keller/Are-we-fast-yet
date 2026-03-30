MODULE Out;
IMPORT SYSTEM;

(* 
  Inline assembly to invoke Linux 'sys_write' (syscall 4).
  Caller pushes 'buf' then 'len'.
*)
PROCEDURE -Write(buf, len: LONGINT);
CODE {SYSTEM.i386}
  DB 05AH                 (* POP EDX     ; EDX = len (cleans up stack) *)
  DB 059H                 (* POP ECX     ; ECX = buf (cleans up stack) *)
  DB 053H                 (* PUSH EBX    ; Save EBX *)
  DB 0BBH, 001H, 0, 0, 0  (* MOV EBX, 1  ; EBX = 1 (stdout) *)
  DB 0B8H, 004H, 0, 0, 0  (* MOV EAX, 4  ; EAX = 4 (sys_write) *)
  DB 0CDH, 080H           (* INT 0x80    ; Syscall *)
  DB 05BH                 (* POP EBX     ; Restore EBX *)
END Write;

PROCEDURE String* (str: ARRAY OF CHAR);
VAR len: LONGINT;
BEGIN
  len := 0;
  WHILE (len < LEN(str)) & (str[len] # 0X) DO INC(len) END;
  IF len > 0 THEN
    Write(SYSTEM.ADR(str[0]), len)
  END
END String;

PROCEDURE Ln*;
VAR ch: CHAR;
BEGIN
  ch := 0AX; (* Line Feed *)
  Write(SYSTEM.ADR(ch), 1)
END Ln;

PROCEDURE Int* (i: LONGINT; n: INTEGER);
VAR
  buf: ARRAY 16 OF CHAR;
  j, k: INTEGER;
  neg: BOOLEAN;
  t: CHAR;
BEGIN
  (* Handle the edge case of maximum negative number *)
  IF i = MIN(LONGINT) THEN
    WHILE n > 11 DO String(" "); DEC(n) END;
    String("-2147483648");
    RETURN
  END;

  neg := i < 0;
  IF neg THEN i := -i END;

  j := 0;
  REPEAT
    buf[j] := CHR(i MOD 10 + ORD("0"));
    i := i DIV 10;
    INC(j)
  UNTIL i = 0;

  IF neg THEN buf[j] := "-"; INC(j) END;

  (* Padding *)
  WHILE n > j DO String(" "); DEC(n) END;

  (* Digits are backwards, reverse them in place *)
  k := 0;
  WHILE k < j DIV 2 DO
    t := buf[k]; 
    buf[k] := buf[j - 1 - k]; 
    buf[j - 1 - k] := t;
    INC(k)
  END;
  
  buf[j] := 0X;
  String(buf)
END Int;

PROCEDURE LongReal* (x: LONGREAL; n: INTEGER);
VAR
  intPart: LONGINT;
  frac: LONGREAL;
  i, d: INTEGER;
  ch: CHAR;
BEGIN
  IF x < 0.0 THEN String("-"); x := -x END;

  (* Barebones safeguard against LONGINT overflow. *)
  IF x > 2147483647.0 THEN
    String("<LARGE REAL>"); RETURN
  END;

  intPart := ENTIER(x);
  frac := x - intPart;
  
  Int(intPart, 0);
  String(".");

  (* Hardcoded to print 6 decimal digits for simplicity *)
  FOR i := 1 TO 6 DO
    frac := frac * 10.0;
    d := SHORT(ENTIER(frac));
    ch := CHR(d + ORD("0"));
    Write(SYSTEM.ADR(ch), 1);
    frac := frac - d;
  END
END LongReal;

END Out.