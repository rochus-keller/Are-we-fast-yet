(*
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
 *
 * This benchmark is derived from Mario Wolczko's Java and Smalltalk version of
 * Richards.
 *
 * License details:
 *   http://web.archive.org/web/20050825101121/http://www.sunlabs.com/people/mario/java_benchmarking/index.html
 *)
 
MODULE Richards;

(*
  This is a completely new translation of the Richards benchmark, based
  directly on the C implementation. This version follows the exact
  data structures, state management, and algorithmic flow of the C code.
*)

IMPORT Benchmark, SOM, Out, SYSTEM;

CONST
  IDLER*     = 0;
  WORKER*    = 1;
  HANDLERA* = 2;
  HANDLERB* = 3;
  DEVICEA*  = 4;
  DEVICEB*  = 5;
  NUMTYPES* = 6;
  DEVICEPACKETKIND* = 0;
  WORKPACKETKIND*   = 1;
  DATASIZE* = 4;

TYPE
  INT32 = SOM.INT32;

  (* Forward declarations matching the C structure *)
  RBObject* = POINTER TO RBObjectDesc;
  Packet* = POINTER TO PacketDesc;
  TaskState* = POINTER TO TaskStateDesc;
  TaskControlBlock* = POINTER TO TaskControlBlockDesc;
  RichardsScheduler* = POINTER TO RichardsSchedulerDesc;
  
  (* Data record types for task-specific data *)
  DeviceTaskDataRecord* = POINTER TO DeviceTaskDataRD;
  HandlerTaskDataRecord* = POINTER TO HandlerTaskDataRD;
  IdleTaskDataRecord* = POINTER TO IdleTaskDataRD;
  WorkerTaskDataRecord* = POINTER TO WorkerTaskDataRD;

  (* Task function signature *)
  TaskFunction* = PROCEDURE (work: Packet; handle: RBObject): TaskControlBlock;

  (* Base object - matches C struct RBObject *)
  RBObjectDesc* = RECORD (SOM.ObjectDesc)
    next: RBObject;
  END;

  (* Packet structure - matches C struct Packet exactly *)
  PacketDesc* = RECORD (RBObjectDesc)
    link: Packet;
    identity: INT32;
    kind: INT32;
    datum: INT32;
    data: ARRAY DATASIZE OF INT32;
  END;

  (* Task state - matches C struct TaskState *)
  TaskStateDesc* = RECORD (RBObjectDesc)
    packetPending: BOOLEAN;
    taskWaiting: BOOLEAN;
    taskHolding: BOOLEAN;
  END;

  (* Task control block - matches C structure *)
  TaskControlBlockDesc* = RECORD (TaskStateDesc)
    link: TaskControlBlock;
    identity: INT32;
    priority: INT32;
    input: Packet;
    handle: RBObject;
    function: TaskFunction;
  END;

  (* Task data records *)
  DeviceTaskDataRD* = RECORD (RBObjectDesc)
    pending: Packet;
  END;

  HandlerTaskDataRD* = RECORD (RBObjectDesc)
    workIn: Packet;
    deviceIn: Packet;
  END;

  IdleTaskDataRD* = RECORD (RBObjectDesc)
    control: INT32;
    count: INT32;
  END;

  WorkerTaskDataRD* = RECORD (RBObjectDesc)
    destination: INT32;
    count: INT32;
  END;

  (* Main scheduler *)
  RichardsSchedulerDesc* = RECORD (RBObjectDesc)
    taskList: TaskControlBlock;
    currentTask: TaskControlBlock;
    currentTaskIdentity: INT32;
    taskTable: POINTER TO ARRAY OF TaskControlBlock;
    queueCount: INT32;
    holdCount: INT32;
  END;

  (* Main benchmark record *)
  Richards* = POINTER TO RichardsDesc;
  RichardsDesc* = RECORD (Benchmark.BenchmarkDesc)
  END;

  (* Result wrapper *)
  BooleanObject* = POINTER TO BooleanObjectDesc;
  BooleanObjectDesc* = RECORD (SOM.ObjectDesc)
    value: BOOLEAN;
  END;

VAR
  scheduler*: RichardsScheduler;
  NOWORK*: Packet;
  NOTASK*: TaskControlBlock;

(* --- Forward Declarations --- *)
PROCEDURE^ HoldSelf(s: RichardsScheduler): TaskControlBlock;
PROCEDURE^ Release(s: RichardsScheduler; identity: INT32): TaskControlBlock;
PROCEDURE^ Wait(s: RichardsScheduler): TaskControlBlock;
PROCEDURE^ QueuePacket(s: RichardsScheduler; packet: Packet): TaskControlBlock;

(* --- Helper Procedures (matching C functions exactly) --- *)

(* Matches C RBObject_append function exactly *)
PROCEDURE RBObjectAppend(packet: Packet; queueHead: Packet): Packet;
  VAR mouse, link: Packet;
BEGIN
  packet.link := NOWORK;
  IF queueHead = NOWORK THEN
    RETURN packet;
  END;
  
  mouse := queueHead;
  link := mouse.link;
  WHILE link # NOWORK DO
    mouse := link;
    link := mouse.link;
  END;
  mouse.link := packet;
  RETURN queueHead;
END RBObjectAppend;

(* --- Task Functions (matching C implementations) --- *)

PROCEDURE IdlerTaskFunction(work: Packet; handle: RBObject): TaskControlBlock;
  VAR data: IdleTaskDataRecord;
BEGIN
  data := handle(IdleTaskDataRecord);
  DEC(data.count);
  IF data.count = 0 THEN
    RETURN HoldSelf(scheduler);
  ELSE
    IF (data.control MOD 2) = 0 THEN
      data.control := data.control DIV 2;
      RETURN Release(scheduler, DEVICEA);
    ELSE
      data.control := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, data.control DIV 2) / SYSTEM.VAL(SET, 53256));
      RETURN Release(scheduler, DEVICEB);
    END;
  END;
END IdlerTaskFunction;

PROCEDURE WorkerTaskFunction(work: Packet; handle: RBObject): TaskControlBlock;
  VAR data: WorkerTaskDataRecord;
      i: INT32;
BEGIN
  data := handle(WorkerTaskDataRecord);
  IF work # NOWORK THEN
    IF data.destination = HANDLERA THEN
      data.destination := HANDLERB;
    ELSE
      data.destination := HANDLERA;
    END;
    work.identity := data.destination;
    work.datum := 0;
    FOR i := 0 TO DATASIZE - 1 DO
      INC(data.count);
      IF data.count > 26 THEN
        data.count := 1;
      END;
      work.data[i] := 64 + data.count;
    END;
    RETURN QueuePacket(scheduler, work);
  ELSE
    RETURN Wait(scheduler);
  END;
END WorkerTaskFunction;

PROCEDURE HandlerTaskFunction(work: Packet; handle: RBObject): TaskControlBlock;
  VAR data: HandlerTaskDataRecord;
      workPacket, devicePacket: Packet;
      count: INT32;
BEGIN
  data := handle(HandlerTaskDataRecord);
  IF work # NOWORK THEN
    IF work.kind = WORKPACKETKIND THEN
      data.workIn := RBObjectAppend(work, data.workIn);
    ELSE
      data.deviceIn := RBObjectAppend(work, data.deviceIn);
    END;
  END;
  
  workPacket := data.workIn;
  IF workPacket # NOWORK THEN
    count := workPacket.datum;
    IF count >= DATASIZE THEN
      data.workIn := workPacket.link;
      RETURN QueuePacket(scheduler, workPacket);
    ELSE
      devicePacket := data.deviceIn;
      IF devicePacket # NOWORK THEN
        data.deviceIn := devicePacket.link;
        devicePacket.datum := workPacket.data[count];
        workPacket.datum := count + 1;
        RETURN QueuePacket(scheduler, devicePacket);
      ELSE
        RETURN Wait(scheduler);
      END;
    END;
  ELSE
    RETURN Wait(scheduler);
  END;
END HandlerTaskFunction;

PROCEDURE DeviceTaskFunction(work: Packet; handle: RBObject): TaskControlBlock;
  VAR data: DeviceTaskDataRecord;
      functionWork: Packet;
BEGIN
  data := handle(DeviceTaskDataRecord);
  functionWork := work;
  IF functionWork # NOWORK THEN
    data.pending := functionWork;
    RETURN HoldSelf(scheduler);
  ELSE
    functionWork := data.pending;
    IF functionWork # NOWORK THEN
      data.pending := NOWORK;
      RETURN QueuePacket(scheduler, functionWork);
    ELSE
      RETURN Wait(scheduler);
    END;
  END;
END DeviceTaskFunction;

(* --- Scheduler Implementation --- *)

PROCEDURE CreatePacket(link: Packet; identity: INT32; kind: INT32): Packet;
  VAR p: Packet;
      i: INT32;
BEGIN
  NEW(p);
  p.link := link;
  p.identity := identity;
  p.kind := kind;
  p.datum := 0;
  FOR i := 0 TO DATASIZE - 1 DO
    p.data[i] := 0;
  END;
  RETURN p;
END CreatePacket;

PROCEDURE CreateTaskState(): TaskState;
  VAR ts: TaskState;
BEGIN
  NEW(ts);
  ts.packetPending := FALSE;
  ts.taskWaiting := FALSE;
  ts.taskHolding := FALSE;
  RETURN ts;
END CreateTaskState;

PROCEDURE TaskStatePacketPending(ts: TaskState);
BEGIN
  ts.packetPending := TRUE;
  ts.taskWaiting := FALSE;
  ts.taskHolding := FALSE;
END TaskStatePacketPending;

PROCEDURE TaskStateRunning(ts: TaskState);
BEGIN
  ts.packetPending := FALSE;
  ts.taskWaiting := FALSE;
  ts.taskHolding := FALSE;
END TaskStateRunning;

PROCEDURE TaskStateWaiting(ts: TaskState);
BEGIN
  ts.packetPending := FALSE;
  ts.taskHolding := FALSE;
  ts.taskWaiting := TRUE;
END TaskStateWaiting;

PROCEDURE TaskStateWaitWithPacket(ts: TaskState);
BEGIN
  ts.taskHolding := FALSE;
  ts.taskWaiting := TRUE;
  ts.packetPending := TRUE;
END TaskStateWaitWithPacket;

PROCEDURE IsTaskHoldingOrWaiting(ts: TaskState): BOOLEAN;
BEGIN
  RETURN ts.taskHolding OR (~ts.packetPending & ts.taskWaiting);
END IsTaskHoldingOrWaiting;

PROCEDURE IsWaitingWithPacket(ts: TaskState): BOOLEAN;
BEGIN
  RETURN ts.packetPending & ts.taskWaiting & ~ts.taskHolding;
END IsWaitingWithPacket;

PROCEDURE CreateTask(s: RichardsScheduler; identity: INT32; priority: INT32; work: Packet; state: TaskState; data: RBObject; fn: TaskFunction);
  VAR t: TaskControlBlock;
BEGIN
  NEW(t);
  t.link := s.taskList;
  t.identity := identity;
  t.priority := priority;
  t.input := work;
  t.handle := data;
  t.function := fn;
  t.packetPending := state.packetPending;
  t.taskWaiting := state.taskWaiting;
  t.taskHolding := state.taskHolding;
  s.taskList := t;
  s.taskTable[identity] := t;
END CreateTask;

PROCEDURE FindTask(s: RichardsScheduler; identity: INT32): TaskControlBlock;
  VAR t: TaskControlBlock;
BEGIN
  t := s.taskTable[identity];
  IF t = NOTASK THEN
    HALT(101);
  END;
  RETURN t;
END FindTask;

PROCEDURE HoldSelf(s: RichardsScheduler): TaskControlBlock;
BEGIN
  INC(s.holdCount);
  s.currentTask.taskHolding := TRUE;
  RETURN s.currentTask.link;
END HoldSelf;

PROCEDURE Release(s: RichardsScheduler; identity: INT32): TaskControlBlock;
  VAR task: TaskControlBlock;
BEGIN
  task := FindTask(s, identity);
  task.taskHolding := FALSE;
  IF task.priority > s.currentTask.priority THEN
    RETURN task;
  ELSE
    RETURN s.currentTask;
  END;
END Release;

PROCEDURE Wait(s: RichardsScheduler): TaskControlBlock;
BEGIN
  s.currentTask.taskWaiting := TRUE;
  RETURN s.currentTask;
END Wait;

PROCEDURE AddInputAndCheckPrio(task: TaskControlBlock; packet: Packet; oldTask: TaskControlBlock): TaskControlBlock;
BEGIN
  IF task.input = NOWORK THEN
    task.input := packet;
    task.packetPending := TRUE;
    IF task.priority > oldTask.priority THEN
      RETURN task;
    END;
  ELSE
    task.input := RBObjectAppend(packet, task.input);
  END;
  RETURN oldTask;
END AddInputAndCheckPrio;

PROCEDURE QueuePacket(s: RichardsScheduler; packet: Packet): TaskControlBlock;
  VAR task: TaskControlBlock;
BEGIN
  task := FindTask(s, packet.identity);
  IF task = NOTASK THEN
    RETURN NOTASK;
  END;
  
  INC(s.queueCount);
  packet.link := NOWORK;
  packet.identity := s.currentTaskIdentity;
  RETURN AddInputAndCheckPrio(task, packet, s.currentTask);
END QueuePacket;

PROCEDURE RunTask(task: TaskControlBlock): TaskControlBlock;
  VAR message: Packet;
BEGIN
  IF IsWaitingWithPacket(task) THEN
    message := task.input;
    task.input := message.link;
    IF task.input # NOWORK THEN
      TaskStatePacketPending(task);
    ELSE
      TaskStateRunning(task);
    END;
  ELSE
    message := NOWORK;
  END;
  RETURN task.function(message, task.handle);
END RunTask;

PROCEDURE Schedule(s: RichardsScheduler);
BEGIN
  s.currentTask := s.taskList;
  WHILE s.currentTask # NOTASK DO
    IF IsTaskHoldingOrWaiting(s.currentTask) THEN
      s.currentTask := s.currentTask.link;
    ELSE
      s.currentTaskIdentity := s.currentTask.identity;
      s.currentTask := RunTask(s.currentTask);
    END;
  END;
END Schedule;

PROCEDURE Start(s: RichardsScheduler): BOOLEAN;
  VAR workQ: Packet;
      running, waiting, waitingWithPacket: TaskState;
      idleData: IdleTaskDataRecord;
      workerData: WorkerTaskDataRecord;
      handlerAData, handlerBData: HandlerTaskDataRecord;
      deviceAData, deviceBData: DeviceTaskDataRecord;
BEGIN
  running := CreateTaskState();
  TaskStateRunning(running);
  
  waiting := CreateTaskState();
  TaskStateWaiting(waiting);
  
  waitingWithPacket := CreateTaskState();
  TaskStateWaitWithPacket(waitingWithPacket);
  
  NEW(idleData);
  idleData.control := 1;
  idleData.count := 10000;
  CreateTask(s, IDLER, 0, NOWORK, running, idleData, IdlerTaskFunction);
  
  workQ := CreatePacket(NOWORK, WORKER, WORKPACKETKIND);
  workQ := CreatePacket(workQ, WORKER, WORKPACKETKIND);
  NEW(workerData);
  workerData.destination := HANDLERA;
  workerData.count := 0;
  CreateTask(s, WORKER, 1000, workQ, waitingWithPacket, workerData, WorkerTaskFunction);
  
  workQ := CreatePacket(NOWORK, DEVICEA, DEVICEPACKETKIND);
  workQ := CreatePacket(workQ, DEVICEA, DEVICEPACKETKIND);
  workQ := CreatePacket(workQ, DEVICEA, DEVICEPACKETKIND);
  NEW(handlerAData);
  handlerAData.workIn := NOWORK;
  handlerAData.deviceIn := NOWORK;
  CreateTask(s, HANDLERA, 2000, workQ, waitingWithPacket, handlerAData, HandlerTaskFunction);
  
  workQ := CreatePacket(NOWORK, DEVICEB, DEVICEPACKETKIND);
  workQ := CreatePacket(workQ, DEVICEB, DEVICEPACKETKIND);
  workQ := CreatePacket(workQ, DEVICEB, DEVICEPACKETKIND);
  NEW(handlerBData);
  handlerBData.workIn := NOWORK;
  handlerBData.deviceIn := NOWORK;
  CreateTask(s, HANDLERB, 3000, workQ, waitingWithPacket, handlerBData, HandlerTaskFunction);
  
  NEW(deviceAData);
  deviceAData.pending := NOWORK;
  CreateTask(s, DEVICEA, 4000, NOWORK, waiting, deviceAData, DeviceTaskFunction);
  
  NEW(deviceBData);
  deviceBData.pending := NOWORK;
  CreateTask(s, DEVICEB, 5000, NOWORK, waiting, deviceBData, DeviceTaskFunction);
  
  Schedule(s);
  
  RETURN (s.queueCount = 23246) & (s.holdCount = 9297);
END Start;

(* --- Main Benchmark Procedures --- *)

PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
  VAR s: RichardsScheduler;
      result: BOOLEAN;
      resultObj: BooleanObject;
BEGIN
  NEW(s);
  NEW(s.taskTable, NUMTYPES);
  s.taskList := NOTASK;
  s.currentTask := NOTASK;
  s.currentTaskIdentity := 0;
  s.queueCount := 0;
  s.holdCount := 0;
  scheduler := s;
  
  result := Start(s);
  
  NEW(resultObj);
  resultObj.value := result;
  RETURN resultObj;
END DoBenchmark;

PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  IF result IS BooleanObject THEN
    RETURN result(BooleanObject).value;
  ELSE
    RETURN FALSE;
  END;
END VerifyResult;

PROCEDURE Create*(): Benchmark.Benchmark;
  VAR r: Richards;
BEGIN
  NEW(r);
  r.DoBenchmark := DoBenchmark;
  r.VerifyResult := VerifyResult;
  r.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN r;
END Create;

BEGIN
  NOWORK := NIL;
  NOTASK := NIL;
END Richards.
