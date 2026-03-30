MODULE Input;
IMPORT SYSTEM;

CONST 
  TimeUnit* = 1000000;

TYPE
  TimeVal = RECORD
    sec: LONGINT;
    usec: LONGINT
  END;

VAR
  startTime: TimeVal;

(* 
  Inline assembly to invoke Linux 'sys_gettimeofday' (syscall 78).
  The caller pushes the address of 'tv' (VAR parameter) onto the stack.
*)
PROCEDURE -GetTimeOfDay(VAR tv: TimeVal);
CODE {SYSTEM.i386}
  DB 059H                 (* POP ECX      ; ECX = ADR(tv) (cleans up the 4-byte stack argument) *)
  DB 053H                 (* PUSH EBX     ; Save EBX (OP2 requires EBX to be preserved) *)
  DB 089H, 0CBH           (* MOV EBX, ECX ; EBX = pointer to tv (arg 1) *)
  DB 031H, 0C9H           (* XOR ECX, ECX ; ECX = 0 (timezone = NULL, arg 2) *)
  DB 0B8H, 04EH, 0, 0, 0  (* MOV EAX, 78  ; EAX = 78 (sys_gettimeofday) *)
  DB 0CDH, 080H           (* INT 0x80     ; Syscall *)
  DB 05BH                 (* POP EBX      ; Restore EBX *)
END GetTimeOfDay;

PROCEDURE Time* (): LONGINT;
VAR 
  now: TimeVal;
BEGIN
  GetTimeOfDay(now);
  RETURN (now.sec - startTime.sec) * TimeUnit + (now.usec - startTime.usec)
END Time;

BEGIN
  GetTimeOfDay(startTime)
END Input.