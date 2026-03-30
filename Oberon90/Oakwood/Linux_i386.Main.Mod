MODULE Main;
IMPORT SYSTEM, Harness;

(* Inline procedure to invoke Linux 'sys_exit' (syscall 1). *)
PROCEDURE -Exit*(code: LONGINT);
CODE {SYSTEM.i386}
  DB 05BH                 (* POP EBX    ; EBX = code (cleans up stack) *)
  DB 0B8H, 001H, 0, 0, 0  (* MOV EAX, 1 ; EAX = 1 (sys_exit) *)
  DB 0CDH, 080H           (* INT 0x80   ; Syscall (kernel terminates process) *)
END Exit;

BEGIN
  Exit(0)
END Main.
