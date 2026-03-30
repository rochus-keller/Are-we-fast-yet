MODULE Kernel;
IMPORT SYSTEM;

CONST
  B = 32; 
  N = 9; 
  nil = 0;
  MarkBit = 0; ArrayBit = 1; FreeBit = 2; SubObjBit = 3; 
  mark = {MarkBit}; array = {ArrayBit}; free = {FreeBit}; subobj = {SubObjBit};

TYPE
  ADDRESS = LONGINT;
  Name* = ARRAY 32 OF CHAR;
  Cmd* = RECORD name*: Name; adr*: ADDRESS END;
  Module* = POINTER TO ModuleDesc;
  
  ExportDesc* = RECORD
    fp*, adr*: LONGINT;
    nofExp*: INTEGER;
    dsc*: POINTER TO ARRAY OF ExportDesc
  END;
  
  ModuleDesc* = RECORD
    next*: Module;
    name*: Name;
    init*, trapped*: BOOLEAN;
    refcnt*, sb*: LONGINT;
    entries*: ADDRESS;
    cmds*: ADDRESS;
    ptrTab*, tdescs*: ADDRESS;
    imports*: ADDRESS;
    data*, code*, refs*: ADDRESS;
    publics*, privates*: LONGINT;
    nofimp*: INTEGER; import*: ADDRESS;
    nofstrc*: INTEGER; struct*: ADDRESS;
    nofreimp*: INTEGER; reimp*: ADDRESS;
    export*: ExportDesc;
    term*: PROCEDURE
  END;

  Tag = POINTER TO TypeDesc;
  TypeDesc = RECORD size, ptroff: LONGINT END;

  FreeBlockPtr = POINTER TO FreeBlock;
  FreeBlock = RECORD
    tag: Tag;
    size: LONGINT; 
    next: ADDRESS
  END;

  BlockPtr = POINTER TO Block;
  Block = RECORD lastElemToMark, currElem, firstElem: BlockPtr END;

  Blockm4Ptr = POINTER TO Blockm4;
  Blockm4 = RECORD
    tag: Tag;
    lastElemToMark, currElem, firstElem: LONGINT
  END;

  InitPtr = POINTER TO RECORD tag: Tag; z0, z1, z2, z3, z4, z5, z6, z7: LONGINT END;

VAR
  modules*: Module;
  StackOrg: LONGINT;
  firstBlock, endBlock: LONGINT;
  A: ARRAY N+1 OF ADDRESS;
  candidates: ARRAY 1024 OF ADDRESS;
  nofcand: INTEGER;
  firstTry: BOOLEAN;
  ptrElemTag: Tag;
  dummyPtrTag: ARRAY 3 OF LONGINT;
  f: FreeBlockPtr;

(* --- Linux Syscalls & Assembler --- *)

PROCEDURE -MmapHeap(): LONGINT;
CODE {SYSTEM.i386}
  PUSH EBX
  PUSH ESI
  PUSH EDI
  PUSH EBP
  XOR EBX, EBX
  MOV ECX, 1073741824     (* 1 Gigabyte Heap for Storage Benchmark *)
  MOV EDX, 3              (* PROT_READ | PROT_WRITE *)
  MOV ESI, 34             (* MAP_PRIVATE | MAP_ANONYMOUS *)
  MOV EDI, -1
  XOR EBP, EBP
  MOV EAX, 192            (* sys_mmap2 *)
  INT 80H
  POP EBP
  POP EDI
  POP ESI
  POP EBX
END MmapHeap;

PROCEDURE -Exit(code: LONGINT);
CODE {SYSTEM.i386}
  POP EBX
  MOV EAX, 1
  INT 80H
END Exit;

PROCEDURE -GetESP(): LONGINT;
CODE {SYSTEM.i386}
  MOV EAX, ESP
END GetESP;

(* --- Garbage Collector --- *)

PROCEDURE Mark(block: BlockPtr);
  TYPE Tag0 = POINTER TO RECORD ptroff: SET END;
  VAR father, field, currElem: BlockPtr; offset: LONGINT; tag, downtag, marked: Tag0; arraybit: SET;
BEGIN
  SYSTEM.GET(SYSTEM.VAL(ADDRESS, block)-4, tag);
  IF ~(SubObjBit IN SYSTEM.VAL(SET, block)) THEN
    marked := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) + mark);
    IF tag # marked THEN
      SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, marked);
      SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, tag) - array)-4, marked);
      EXCL(SYSTEM.VAL(SET, marked), MarkBit); 
      SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
      INCL(arraybit, MarkBit);
      SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
      arraybit := SYSTEM.VAL(SET, tag) * array;
      IF arraybit # {} THEN currElem := block.firstElem;
        tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) - arraybit)
      ELSE currElem := block
      END;
      father := NIL;
      LOOP
        INC(SYSTEM.VAL(ADDRESS, tag), 4);
        offset := SYSTEM.VAL(LONGINT, tag.ptroff - {ArrayBit});
        IF offset < 0 THEN
          INC(SYSTEM.VAL(ADDRESS, tag), offset);
          IF (arraybit # {}) & (currElem # block.lastElemToMark) THEN
            INC(SYSTEM.VAL(ADDRESS, currElem), SYSTEM.VAL(LONGINT, tag.ptroff - {ArrayBit}))
          ELSE 
            SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, SYSTEM.VAL(SET, tag) + arraybit + mark);
            IF father = NIL THEN EXIT END;
            SYSTEM.GET(SYSTEM.VAL(ADDRESS, father)-4, tag);
            arraybit := SYSTEM.VAL(SET, tag) * array;
            tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, tag) - (array + mark));
            IF arraybit # {} THEN currElem := father.currElem ELSE currElem := father END;
            offset := SYSTEM.VAL(ADDRESS, currElem) + SYSTEM.VAL(LONGINT, tag.ptroff - {ArrayBit});
            SYSTEM.GET(offset, field);
            SYSTEM.PUT(offset, block);
            block := father;
            father := field
          END
        ELSE
          offset := SYSTEM.VAL(ADDRESS, currElem) + offset;
          SYSTEM.GET(offset, field);
          IF field # NIL THEN
            SYSTEM.GET(SYSTEM.VAL(ADDRESS, field)-4, downtag);
            IF subobj * SYSTEM.VAL(SET, field) = {} THEN 
              marked := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, downtag) + mark);
              IF downtag # marked THEN 
                SYSTEM.PUT(SYSTEM.VAL(ADDRESS, field)-4, marked);
                SYSTEM.PUT(SYSTEM.VAL(ADDRESS, block)-4, SYSTEM.VAL(SET, tag) + arraybit + mark);
                IF arraybit # {} THEN block.currElem:= currElem END;
                SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, downtag) - array)-4, marked);
                EXCL(SYSTEM.VAL(SET, marked), MarkBit); 
                SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
                INCL(arraybit, MarkBit);
                SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, arraybit);
                arraybit := SYSTEM.VAL(SET, downtag) * array;
                IF arraybit # {} THEN currElem := field.firstElem ELSE currElem := field END;
                SYSTEM.PUT(offset, father);
                father := block;
                block := field;
                tag := SYSTEM.VAL(Tag0, SYSTEM.VAL(SET, downtag) - arraybit)
              END
            ELSE 
              SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, downtag) - array)-4, marked);
              EXCL(SYSTEM.VAL(SET, marked), MarkBit);
              SYSTEM.GET(SYSTEM.VAL(ADDRESS, marked)-4, downtag);
              INCL(SYSTEM.VAL(SET, downtag), MarkBit);
              SYSTEM.PUT(SYSTEM.VAL(ADDRESS, marked)-4, downtag)
            END
          END
        END
      END
    END
  ELSE 
    SYSTEM.GET(SYSTEM.VAL(ADDRESS, SYSTEM.VAL(SET, tag) - array)-4, tag);
    EXCL(SYSTEM.VAL(SET, tag), MarkBit);
    SYSTEM.GET(SYSTEM.VAL(ADDRESS, tag)-4, arraybit);
    INCL(arraybit, MarkBit);
    SYSTEM.PUT(SYSTEM.VAL(ADDRESS, tag)-4, arraybit)
  END
END Mark;

PROCEDURE Sweep;
  VAR p, end: Blockm4Ptr; lastp: FreeBlockPtr; tag, notmarked, tdesc: Tag; size, lastsize, i: LONGINT;
  lastA: ARRAY N+1 OF ADDRESS;
BEGIN
  i := 0;
  WHILE i <= N DO A[i] := nil; lastA[i] := SYSTEM.ADR(A[i]); INC(i) END;
  p := SYSTEM.VAL(Blockm4Ptr, firstBlock);
  end := SYSTEM.VAL(Blockm4Ptr, endBlock);
  lastsize := 0; 
  WHILE p # end DO
    tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, p.tag) - free);
    notmarked := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, tag) - mark);
    tdesc := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, notmarked) - array);
    IF notmarked # tdesc THEN size := p.lastElemToMark + tdesc.size - SYSTEM.VAL(ADDRESS, p)
    ELSE size := tdesc.size + 4
    END;
    size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size + B-1)-SYSTEM.VAL(SET, B-1));
    IF tag = notmarked THEN 
      IF lastsize = 0 THEN lastp := SYSTEM.VAL(FreeBlockPtr, p) END;
      INC(lastsize, size)
    ELSE
      p.tag := notmarked;
      IF lastsize > 0 THEN
        lastp.size := lastsize - 4;
        lastp.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(lastp.size)) + free);
        i := lastsize DIV B;
        IF i > N THEN i := N END;
        lastp.next := nil;
        SYSTEM.PUT(lastA[i], lastp);
        lastA[i] := SYSTEM.ADR(lastp.next);
        lastsize := 0
      END
    END;
    INC(SYSTEM.VAL(ADDRESS, p), size)
  END;
  IF lastsize > 0 THEN
    lastp.size := lastsize - 4;
    lastp.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(lastp.size)) + free);
    i := lastsize DIV B;
    IF i > N THEN i := N END;
    lastp.next := nil;
    SYSTEM.PUT(lastA[i], lastp);
    lastA[i] := SYSTEM.ADR(lastp.next)
  END
END Sweep;

PROCEDURE CheckCandidates; 
  VAR i, j, h, p: LONGINT; block: Blockm4Ptr; tag, notmarked, tdesc: Tag;
BEGIN
  h := 1; REPEAT h := h*3 + 1 UNTIL h > nofcand;
  REPEAT h := h DIV 3; i := h;
    WHILE i < nofcand DO p := candidates[i]; j := i;
      WHILE (j >= h) & (candidates[j-h] > p) DO
        candidates[j] := candidates[j-h]; j := j-h;
      END;
      candidates[j] := p; INC(i)
    END
  UNTIL h = 1;
  block := SYSTEM.VAL(Blockm4Ptr, firstBlock);
  i := 0; p := candidates[i];
  LOOP
    IF p <= SYSTEM.VAL(ADDRESS, block) + 4 THEN
      IF p = SYSTEM.VAL(ADDRESS, block) + 4 THEN Mark(SYSTEM.VAL(BlockPtr, p)) END;
      INC(i); IF i = nofcand THEN EXIT END;
      p := candidates[i]
    ELSIF p <= SYSTEM.VAL(ADDRESS, block) + 28 THEN 
      IF p = SYSTEM.VAL(ADDRESS, block) + 28 THEN Mark(SYSTEM.VAL(BlockPtr, SYSTEM.VAL(ADDRESS, block)+4)) END;
      INC(i); IF i = nofcand THEN EXIT END;
      p := candidates[i]
    ELSE
      tag := block.tag;
      notmarked := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, tag) - (mark + free));
      tdesc := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, notmarked) - array);
      IF notmarked # tdesc THEN h := block.lastElemToMark + tdesc.size - SYSTEM.VAL(ADDRESS, block)
      ELSE h := tdesc.size + 4
      END;
      INC(SYSTEM.VAL(ADDRESS, block), SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, h + B-1)-SYSTEM.VAL(SET, B-1)));
      IF block = SYSTEM.VAL(Blockm4Ptr, endBlock) THEN EXIT END
    END
  END;
  nofcand := 0
END CheckCandidates;

PROCEDURE Candidate(p: LONGINT);
  VAR tag, tag0: LONGINT;
BEGIN
  IF (p >= firstBlock) & (p < endBlock) THEN
    IF p MOD B = 0 THEN
      SYSTEM.GET(p-4, tag);
      IF tag MOD 8 IN {0, 2} THEN 
        candidates[nofcand] := p; INC(nofcand);
        IF nofcand = LEN(candidates) THEN CheckCandidates END
      END
    ELSIF p MOD 16 = 8 THEN 
      SYSTEM.GET(p-4, tag);
      IF (tag MOD B = 0) & (tag >= firstBlock) & (tag < endBlock) THEN
        SYSTEM.GET(tag-4, tag0);
        IF tag0 = tag THEN
          candidates[nofcand] := p; INC(nofcand);
          IF nofcand = LEN(candidates) THEN CheckCandidates END
        END
      END
    END
  END
END Candidate;

PROCEDURE GC*;
  VAR m: Module; i, p, sp, ptradr: LONGINT; ptr: BlockPtr;
BEGIN
  m := modules;
  WHILE m # NIL DO
    Mark(SYSTEM.VAL(BlockPtr, m)); 
    
    i := 0;
    SYSTEM.GET(m.ptrTab + 16, i);
    ptradr := m.ptrTab + 20; 
    WHILE i > 0 DO
      SYSTEM.GET(ptradr, p); SYSTEM.GET(p, ptr);
      IF ptr # NIL THEN Mark(ptr) END;
      DEC(i); INC(ptradr, 4);
    END;
    
    i := 0;
    SYSTEM.GET(m.tdescs + 16, i);
    ptradr := m.tdescs + 20; 
    WHILE i > 0 DO
      SYSTEM.GET(ptradr, ptr); Mark(ptr);
      DEC(i); INC(ptradr, 4);
    END;
    
    m := m.next;
  END;
  sp := GetESP();
  nofcand := 0;
  WHILE sp < StackOrg DO
    SYSTEM.GET(sp, p); Candidate(p); INC(sp, 4)
  END;
  IF nofcand > 0 THEN CheckCandidates END;
  Sweep
END GC;

(* --- Allocation --- *)

PROCEDURE NewBlock(size: LONGINT): InitPtr;
  VAR i, rest: LONGINT; adr, AN: ADDRESS; ptr: InitPtr; restptr: FreeBlockPtr;
BEGIN
  i := size DIV B;
  IF i > N THEN i := N END;
  adr := SYSTEM.ADR(A[0]) + 4*i;
  AN := SYSTEM.ADR(A[N]);
  LOOP
    SYSTEM.GET(adr, ptr);
    IF adr = AN THEN
      LOOP
        IF ptr = NIL THEN
          IF firstTry THEN 
            GC; firstTry := FALSE; 
            ptr := NewBlock(size); 
            firstTry := TRUE; RETURN ptr
          ELSE Exit(14) (* OOM *)
          END
        END;
        IF ptr.z0 + 4 >= size THEN EXIT END;
        adr := SYSTEM.ADR(ptr.z1); SYSTEM.GET(adr, ptr)
      END;
      EXIT
    END;
    IF ptr # NIL THEN EXIT END;
    INC(adr, 4)
  END;
  SYSTEM.PUT(adr, ptr.z1);
  rest := ptr.z0 + 4 - size;
  restptr := SYSTEM.VAL(FreeBlockPtr, SYSTEM.VAL(ADDRESS, ptr) + size);
  IF rest > 0 THEN 
    i := rest DIV B; IF i > N THEN i := N END;
    restptr.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(restptr.size)) + free);
    restptr.size := rest - 4;
    restptr.next := A[i]; A[i] := SYSTEM.VAL(ADDRESS, restptr)
  END;
  RETURN ptr
END NewBlock;

PROCEDURE NewRec*(VAR p: ADDRESS; tag: Tag);
  VAR size, i: LONGINT; ptr: InitPtr; 
BEGIN 
  IF tag = NIL THEN tag := ptrElemTag END; 
  size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, tag.size + 4 + B-1)-SYSTEM.VAL(SET, B-1));
  ptr := NewBlock(size);
  FOR i := SYSTEM.VAL(ADDRESS, ptr) + 4 TO SYSTEM.VAL(ADDRESS, ptr) + size - 4 BY 4 DO SYSTEM.PUT(i, 0) END;
  ptr.tag := tag;
  p := SYSTEM.VAL(ADDRESS, ptr) + 4
END NewRec;

PROCEDURE NewSys*(VAR p: ADDRESS; size: LONGINT);
  VAR ptr: InitPtr; i: LONGINT;
BEGIN
  size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, size + 28 + B-1)-SYSTEM.VAL(SET, B-1));
  ptr := NewBlock(size);
  FOR i := SYSTEM.VAL(ADDRESS, ptr) + 4 TO SYSTEM.VAL(ADDRESS, ptr) + size - 4 BY 4 DO SYSTEM.PUT(i, 0) END;
  ptr.tag := SYSTEM.VAL(Tag, SYSTEM.ADR(ptr.z0));
  ptr.z0 := size - 4;
  ptr.z1 := -4;
  ptr.z5 := SYSTEM.ADR(ptr.z0);
  p := SYSTEM.VAL(ADDRESS, ptr) + 28;
END NewSys;

PROCEDURE NewArr*(VAR p: ADDRESS; eltag: Tag; nofelem, nofdim: LONGINT);
  VAR size, firstElem, elSize, arrSize, vectSize, i: LONGINT; ptr: InitPtr; 
BEGIN
  IF eltag = NIL THEN eltag := ptrElemTag END;
  elSize := eltag.size;
  arrSize := nofelem*elSize;
  IF arrSize=0 THEN NewSys(p, nofdim*4+12); RETURN END;
  vectSize := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, 4*nofdim) + SYSTEM.VAL(SET, 4)); 
  IF eltag.ptroff = -4 THEN 
    NewSys(p, arrSize + vectSize + 12);
    SYSTEM.PUT(p, SYSTEM.VAL(SET, arrSize + vectSize+15)-SYSTEM.VAL(SET, 3));
    RETURN
  END;
  size := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, arrSize + vectSize + 16 + B-1)-SYSTEM.VAL(SET, B-1));
  ptr := NewBlock(size);
  FOR i := SYSTEM.VAL(ADDRESS, ptr) + 4 TO SYSTEM.VAL(ADDRESS, ptr) + size - 4 BY 4 DO SYSTEM.PUT(i, 0) END;
  ptr.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, eltag) + array);
  firstElem := SYSTEM.ADR(ptr.z3) + vectSize;
  ptr.z0 := firstElem + arrSize - elSize;
  ptr.z2 := firstElem;
  p := SYSTEM.VAL(ADDRESS, ptr) + 4;
END NewArr;

BEGIN
  (* Calculate StackOrg securely by masking off the lower bits to align to the top 
     of the Linux 4K memory page (0xFFFFF000). *)
  StackOrg := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, GetESP() + 4095) * SYSTEM.VAL(SET, 0FFFFF000H));

  firstTry := TRUE;

  firstBlock := MmapHeap();
  IF (firstBlock < 0) & (firstBlock > -4096) THEN Exit(99) END;
  
  (* Align firstBlock so that the block header (firstBlock) is 28 MOD 32.
     This ensures the user pointer (firstBlock + 4) is 0 MOD 32, exactly matching the 
     expectations of Candidate() stack scanning and the Garbage Collector! *)
  firstBlock := SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET, firstBlock + 4 + 31) - SYSTEM.VAL(SET, 31)) - 4;
  endBlock := firstBlock + 1073741824 - B;

  FOR nofcand := 0 TO N DO A[nofcand] := nil END;
  
  A[N] := firstBlock;
  f := SYSTEM.VAL(FreeBlockPtr, firstBlock);
  f.tag := SYSTEM.VAL(Tag, SYSTEM.VAL(SET, SYSTEM.ADR(f.size)) + free);
  f.size := endBlock - firstBlock - 4;
  f.next := nil;

  dummyPtrTag[0] := 4;  
  dummyPtrTag[1] := 0;  
  dummyPtrTag[2] := -8; (* Correct jump-back length for ptrElemTag *)
  ptrElemTag := SYSTEM.VAL(Tag, SYSTEM.ADR(dummyPtrTag[0]));
END Kernel.

