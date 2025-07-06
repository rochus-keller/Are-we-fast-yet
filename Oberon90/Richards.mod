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
  HANDLER_A* = 2;
  HANDLER_B* = 3;
  DEVICE_A*  = 4;
  DEVICE_B*  = 5;
  NUM_TYPES* = 6;
  DEVICE_PACKET_KIND* = 0;
  WORK_PACKET_KIND*   = 1;
  DATA_SIZE* = 4;

TYPE
  INT32 = SOM.INT32;

  (* Forward declarations matching the C structure *)
  RBObject* = POINTER TO RBObjectDesc;
  Packet* = POINTER TO PacketDesc;
  TaskState* = POINTER TO TaskStateDesc;
  TaskControlBlock* = POINTER TO TaskControlBlockDesc;
  RichardsScheduler* = POINTER TO RichardsSchedulerDesc;
  
  (* Data record types for task-specific data *)
  DeviceTaskDataRecord* = POINTER TO DeviceTaskDataRecordDesc;
  HandlerTaskDataRecord* = POINTER TO HandlerTaskDataRecordDesc;
  IdleTaskDataRecord* = POINTER TO IdleTaskDataRecordDesc;
  WorkerTaskDataRecord* = POINTER TO WorkerTaskDataRecordDesc;

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
    data: ARRAY DATA_SIZE OF INT32;
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
  DeviceTaskDataRecordDesc* = RECORD (RBObjectDesc)
    pending: Packet;
  END;

  HandlerTaskDataRecordDesc* = RECORD (RBObjectDesc)
    workIn: Packet;
    deviceIn: Packet;
  END;

  IdleTaskDataRecordDesc* = RECORD (RBObjectDesc)
    control: INT32;
    count: INT32;
  END;

  WorkerTaskDataRecordDesc* = RECORD (RBObjectDesc)
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
  NO_WORK*: Packet;
  NO_TASK*: TaskControlBlock;

(* --- Forward Declarations --- *)
PROCEDURE^ HoldSelf(s: RichardsScheduler): TaskControlBlock;
PROCEDURE^ Release(s: RichardsScheduler; identity: INT32): TaskControlBlock;
PROCEDURE^ Wait(s: RichardsScheduler): TaskControlBlock;
PROCEDURE^ QueuePacket(s: RichardsScheduler; p: Packet): TaskControlBlock;

(* --- Helper Procedures (matching C functions exactly) --- *)

(* Matches C RBObject_append function exactly *)
PROCEDURE RBObjectAppend(packet: Packet; queueHead: Packet): Packet;
  VAR mouse, link: Packet;
BEGIN
  packet.link := NO_WORK;
  IF queueHead = NO_WORK THEN
    RETURN packet;
  END;
  
  mouse := queueHead;
  link := mouse.link;
  WHILE link # NO_WORK DO
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
      RETURN Release(scheduler, DEVICE_A);
    ELSE
      data.control := SYSTEM.VAL(INT32, SYSTEM.VAL(SET, data.control DIV 2) / SYSTEM.VAL(SET, 53256));
      RETURN Release(scheduler, DEVICE_B);
    END;
  END;
END IdlerTaskFunction;

PROCEDURE WorkerTaskFunction(work: Packet; handle: RBObject): TaskControlBlock;
  VAR data: WorkerTaskDataRecord;
      i: INT32;
BEGIN
  data := handle(WorkerTaskDataRecord);
  IF work # NO_WORK THEN
    IF data.destination = HANDLER_A THEN
      data.destination := HANDLER_B;
    ELSE
      data.destination := HANDLER_A;
    END;
    work.identity := data.destination;
    work.datum := 0;
    FOR i := 0 TO DATA_SIZE - 1 DO
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
  IF work # NO_WORK THEN
    IF work.kind = WORK_PACKET_KIND THEN
      data.workIn := RBObjectAppend(work, data.workIn);
    ELSE
      data.deviceIn := RBObjectAppend(work, data.deviceIn);
    END;
  END;
  
  workPacket := data.workIn;
  IF workPacket # NO_WORK THEN
    count := workPacket.datum;
    IF count >= DATA_SIZE THEN
      data.workIn := workPacket.link;
      RETURN QueuePacket(scheduler, workPacket);
    ELSE
      devicePacket := data.deviceIn;
      IF devicePacket # NO_WORK THEN
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
  IF functionWork # NO_WORK THEN
    data.pending := functionWork;
    RETURN HoldSelf(scheduler);
  ELSE
    functionWork := data.pending;
    IF functionWork # NO_WORK THEN
      data.pending := NO_WORK;
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
  FOR i := 0 TO DATA_SIZE - 1 DO
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

PROCEDURE TaskStateWaitingWithPacket(ts: TaskState);
BEGIN
  ts.taskHolding := FALSE;
  ts.taskWaiting := TRUE;
  ts.packetPending := TRUE;
END TaskStateWaitingWithPacket;

PROCEDURE IsTaskHoldingOrWaiting(ts: TaskState): BOOLEAN;
BEGIN
  RETURN ts.taskHolding OR (~ts.packetPending & ts.taskWaiting);
END IsTaskHoldingOrWaiting;

PROCEDURE IsWaitingWithPacket(ts: TaskState): BOOLEAN;
BEGIN
  RETURN ts.packetPending & ts.taskWaiting & ~ts.taskHolding;
END IsWaitingWithPacket;

PROCEDURE CreateTask(s: RichardsScheduler; identity: INT32; priority: INT32; work: Packet; state: TaskState; data: RBObject; fn: TaskFunction): TaskControlBlock;
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
  RETURN t;
END CreateTask;

PROCEDURE FindTask(s: RichardsScheduler; identity: INT32): TaskControlBlock;
  VAR t: TaskControlBlock;
BEGIN
  t := s.taskTable[identity];
  IF t = NO_TASK THEN
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

PROCEDURE AddInputAndCheckPriority(task: TaskControlBlock; packet: Packet; oldTask: TaskControlBlock): TaskControlBlock;
BEGIN
  IF task.input = NO_WORK THEN
    task.input := packet;
    task.packetPending := TRUE;
    IF task.priority > oldTask.priority THEN
      RETURN task;
    END;
  ELSE
    task.input := RBObjectAppend(packet, task.input);
  END;
  RETURN oldTask;
END AddInputAndCheckPriority;

PROCEDURE QueuePacket(s: RichardsScheduler; packet: Packet): TaskControlBlock;
  VAR task: TaskControlBlock;
BEGIN
  task := FindTask(s, packet.identity);
  IF task = NO_TASK THEN
    RETURN NO_TASK;
  END;
  
  INC(s.queueCount);
  packet.link := NO_WORK;
  packet.identity := s.currentTaskIdentity;
  RETURN AddInputAndCheckPriority(task, packet, s.currentTask);
END QueuePacket;

PROCEDURE RunTask(task: TaskControlBlock): TaskControlBlock;
  VAR message: Packet;
BEGIN
  IF IsWaitingWithPacket(task) THEN
    message := task.input;
    task.input := message.link;
    IF task.input # NO_WORK THEN
      TaskStatePacketPending(task);
    ELSE
      TaskStateRunning(task);
    END;
  ELSE
    message := NO_WORK;
  END;
  RETURN task.function(message, task.handle);
END RunTask;

PROCEDURE Schedule(s: RichardsScheduler);
BEGIN
  s.currentTask := s.taskList;
  WHILE s.currentTask # NO_TASK DO
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
  TaskStateWaitingWithPacket(waitingWithPacket);
  
  NEW(idleData);
  idleData.control := 1;
  idleData.count := 10000;
  CreateTask(s, IDLER, 0, NO_WORK, running, idleData, IdlerTaskFunction);
  
  workQ := CreatePacket(NO_WORK, WORKER, WORK_PACKET_KIND);
  workQ := CreatePacket(workQ, WORKER, WORK_PACKET_KIND);
  NEW(workerData);
  workerData.destination := HANDLER_A;
  workerData.count := 0;
  CreateTask(s, WORKER, 1000, workQ, waitingWithPacket, workerData, WorkerTaskFunction);
  
  workQ := CreatePacket(NO_WORK, DEVICE_A, DEVICE_PACKET_KIND);
  workQ := CreatePacket(workQ, DEVICE_A, DEVICE_PACKET_KIND);
  workQ := CreatePacket(workQ, DEVICE_A, DEVICE_PACKET_KIND);
  NEW(handlerAData);
  handlerAData.workIn := NO_WORK;
  handlerAData.deviceIn := NO_WORK;
  CreateTask(s, HANDLER_A, 2000, workQ, waitingWithPacket, handlerAData, HandlerTaskFunction);
  
  workQ := CreatePacket(NO_WORK, DEVICE_B, DEVICE_PACKET_KIND);
  workQ := CreatePacket(workQ, DEVICE_B, DEVICE_PACKET_KIND);
  workQ := CreatePacket(workQ, DEVICE_B, DEVICE_PACKET_KIND);
  NEW(handlerBData);
  handlerBData.workIn := NO_WORK;
  handlerBData.deviceIn := NO_WORK;
  CreateTask(s, HANDLER_B, 3000, workQ, waitingWithPacket, handlerBData, HandlerTaskFunction);
  
  NEW(deviceAData);
  deviceAData.pending := NO_WORK;
  CreateTask(s, DEVICE_A, 4000, NO_WORK, waiting, deviceAData, DeviceTaskFunction);
  
  NEW(deviceBData);
  deviceBData.pending := NO_WORK;
  CreateTask(s, DEVICE_B, 5000, NO_WORK, waiting, deviceBData, DeviceTaskFunction);
  
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
  NEW(s.taskTable, NUM_TYPES);
  s.taskList := NO_TASK;
  s.currentTask := NO_TASK;
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
  WITH result: BooleanObject DO
    RETURN result.value;
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
  NO_WORK := NIL;
  NO_TASK := NIL;
END Richards.
