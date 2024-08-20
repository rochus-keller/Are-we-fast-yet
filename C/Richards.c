/*
 * Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 *
 * This benchmark is derived from Mario Wolczko's Java and Smalltalk version of
 * Richards.
 *
 * License details:
 *   http://web.archive.org/web/20050825101121/http://www.sunlabs.com/people/mario/java_benchmarking/index.html
 */

#include "Richards.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <assert.h>

typedef struct Packet Packet;
typedef struct TaskControlBlock TaskControlBlock;

static Packet* const NO_WORK = 0;
static TaskControlBlock* const NO_TASK = 0;


enum { IDLER     = 0,
       WORKER    = 1,
       HANDLER_A = 2,
       HANDLER_B = 3,
       DEVICE_A  = 4,
       DEVICE_B  = 5,
       NUM_TYPES = 6 };

enum { DEVICE_PACKET_KIND = 0, WORK_PACKET_KIND   = 1 };

typedef struct RBObject RBObject;

static RBObject* toDelete = 0;

struct RBObject {
    RBObject* next;
};

static void RBObject_init(RBObject* o, void * tmp)
{
    o->next = toDelete;
    toDelete = o;
}

static void RBObject_delete(RBObject*o)
{
    if( o->next )
        RBObject_delete(o->next);
    free(o);
}

enum { DATA_SIZE = 4 };

struct Packet {
    RBObject base;

    Packet* link; // ref
    int identity;
    int kind;
    int datum;
    int data[DATA_SIZE];
};

static Packet* Packet_create(Packet* link, int identity, int kind) {
    Packet* me = (Packet*)malloc(sizeof(Packet));
    RBObject_init(me,0);
    me->link     = link;
    me->identity = identity;
    me->kind     = kind;
    me->datum    = 0;
    for( int i = 0; i < DATA_SIZE; i++ )
        me->data[i] = 0;
    return me;
}


static int* Packet_getData(Packet* me) { return me->data; }
static int   Packet_getDatum(Packet* me) { return me->datum; }
static void  Packet_setDatum(Packet* me, int someData) { me->datum = someData; }

static int  Packet_getIdentity(Packet* me) { return me->identity; }
static void Packet_setIdentity(Packet* me, int anIdentity) { me->identity = anIdentity; }

static int Packet_getKind(Packet* me) { return me->kind; }
static Packet* Packet_getLink(Packet* me) { return me->link; }
static void Packet_setLink(Packet* me, Packet* aLink) {
    me->link = aLink;
}


Packet *RBObject_append(Packet *packet, Packet *queueHead)
{
    Packet_setLink(packet, NO_WORK);
    if (NO_WORK == queueHead) {
        return packet;
    }

    Packet* mouse = queueHead; // ref
    Packet* link; // ref
    while (NO_WORK != (link = Packet_getLink(mouse))) {
        mouse = link;
    }
    Packet_setLink(mouse, packet);
    return queueHead;
}

typedef struct TaskState {
    RBObject base;
    bool packetPending_;
    bool taskWaiting;
    bool taskHolding;
} TaskState;

static void TaskState_init(TaskState* me) {
    RBObject_init(me,0);
    me->packetPending_ = false;
    me->taskWaiting = false;
    me->taskHolding = false;
}

static TaskState* TaskState_create() {
    TaskState* me = (TaskState*)malloc(sizeof(TaskState));
    TaskState_init(me);
    return me;
}

static bool TaskState_isPacketPending(TaskState* me) { return me->packetPending_; }
static bool TaskState_isTaskHolding(TaskState* me)   { return me->taskHolding;   }
static bool TaskState_isTaskWaiting(TaskState* me)   { return me->taskWaiting;   }

static void TaskState_setTaskHolding(TaskState* me, bool b) { me->taskHolding = b; }
static void TaskState_setTaskWaiting(TaskState* me, bool b) { me->taskWaiting = b; }
static void TaskState_setPacketPending(TaskState* me, bool b) { me->packetPending_ = b; }

static void TaskState_packetPending(TaskState* me) {
    me->packetPending_ = true;
    me->taskWaiting   = false;
    me->taskHolding   = false;
}

static void TaskState_running(TaskState* me) {
    me->packetPending_ = me->taskWaiting = me->taskHolding = false;
}

static void TaskState_waiting(TaskState* me) {
    me->packetPending_ = me->taskHolding = false;
    me->taskWaiting = true;
}

static void TaskState_waitingWithPacket(TaskState* me) {
    me->taskHolding = false;
    me->taskWaiting = me->packetPending_ = true;
}

static bool TaskState_isRunning(TaskState* me) {
    return !me->packetPending_ && !me->taskWaiting && !me->taskHolding;
}

static bool TaskState_isTaskHoldingOrWaiting(TaskState* me) {
    return me->taskHolding || (!me->packetPending_ && me->taskWaiting);
}

static bool TaskState_isWaiting(TaskState* me) {
    return !me->packetPending_ && me->taskWaiting && !me->taskHolding;
}

static bool TaskState_isWaitingWithPacket(TaskState* me) {
    return me->packetPending_ && me->taskWaiting && !me->taskHolding;
}

static TaskState* TaskState_createPacketPending() {
    TaskState* t = TaskState_create();
    TaskState_packetPending(t);
    return t;
}

static TaskState* TaskState_createRunning() {
    TaskState* t = TaskState_create();
    TaskState_running(t);
    return t;
}

static TaskState* TaskState_createWaiting() {
    TaskState* t = TaskState_create();
    TaskState_waiting(t);
    return t;
}

static TaskState* TaskState_createWaitingWithPacket() {
    TaskState* t = TaskState_create();
    TaskState_waitingWithPacket(t);
    return t;
}

typedef struct ProcessFunction ProcessFunction;

struct ProcessFunction {
    RBObject base;
    TaskControlBlock* (*apply)(ProcessFunction* me, Packet* work, RBObject* word);
};

struct TaskControlBlock {
    TaskState base;
    TaskControlBlock* link; // ref
    int identity;
    int priority;
    Packet* input; // ref
    ProcessFunction* function; // ref
    RBObject* handle; // ref
};


static TaskControlBlock* TaskControlBlock_create(TaskControlBlock* aLink, int anIdentity,
                     int aPriority, Packet* anInitialWorkQueue,
                     TaskState* anInitialState, ProcessFunction* aBlock,
                     RBObject* aPrivateData) {
    TaskControlBlock* me = (TaskControlBlock*)malloc(sizeof(TaskControlBlock));
    TaskState_init(me);
    me->link = aLink;
    me->identity = anIdentity;
    me->priority = aPriority;
    me->input = anInitialWorkQueue;
    TaskState_setPacketPending(me, TaskState_isPacketPending(anInitialState));
    TaskState_setTaskWaiting(me, TaskState_isTaskWaiting(anInitialState));
    TaskState_setTaskHolding(me, TaskState_isTaskHolding(anInitialState));
    me->function = aBlock;
    me->handle = aPrivateData;
    return me;
}

static int TaskControlBlock_getIdentity(TaskControlBlock* me) { return me->identity; }
static TaskControlBlock* TaskControlBlock_getLink(TaskControlBlock* me)  { return me->link; }
static int TaskControlBlock_getPriority(TaskControlBlock* me) { return me->priority; }

static TaskControlBlock* TaskControlBlock_addInputAndCheckPriority(TaskControlBlock* me, Packet* packet,
                                           TaskControlBlock* oldTask) {
    if (NO_WORK == me->input) {
        me->input = packet;
        TaskState_setPacketPending(me, true);
        if (me->priority > TaskControlBlock_getPriority(oldTask)) {
            return me;
        }
    } else {
        Packet* tmp = RBObject_append(packet, me->input);
        me->input = tmp;
    }
    return oldTask;
}

static TaskControlBlock* TaskControlBlock_runTask(TaskControlBlock* me) {
    Packet* message = 0; // ref
    if (TaskState_isWaitingWithPacket(me)) {
        message = me->input;
        me->input = Packet_getLink(message);
        if (NO_WORK == me->input) {
            TaskState_running(me);
        } else {
            TaskState_packetPending(me);
        }
    } else {
        message = NO_WORK;
    }
    TaskControlBlock* res = me->function->apply(me->function, message, me->handle);
    return res;
}


typedef struct DeviceTaskDataRecord {
    RBObject base;
    Packet* pending; // ref
} DeviceTaskDataRecord;

static DeviceTaskDataRecord* DeviceTaskDataRecord_create() {
    DeviceTaskDataRecord* me = (DeviceTaskDataRecord*)malloc(sizeof(DeviceTaskDataRecord));
    RBObject_init(me,0);
    me->pending = NO_WORK;
    return me;
}

static Packet* DeviceTaskDataRecord_getPending(DeviceTaskDataRecord* me) { return me->pending; }

void DeviceTaskDataRecord_setPending(DeviceTaskDataRecord* me, Packet* packet) {
    me->pending = packet;
}


typedef struct HandlerTaskDataRecord {
    RBObject base;
    Packet* workIn_; // ref
    Packet* deviceIn_; // ref
} HandlerTaskDataRecord;

static HandlerTaskDataRecord* HandlerTaskDataRecord_create() {
    HandlerTaskDataRecord* me = (HandlerTaskDataRecord*)malloc(sizeof(HandlerTaskDataRecord));
    RBObject_init(me,0);
    me->workIn_ = me->deviceIn_ = NO_WORK;
    return me;
}

static Packet* HandlerTaskDataRecord_deviceIn(HandlerTaskDataRecord*me) { return me->deviceIn_; }
static void HandlerTaskDataRecord_setDeviceIn(HandlerTaskDataRecord* me, Packet* aPacket) {
    me->deviceIn_ = aPacket;
}

static void HandlerTaskDataRecord_deviceInAdd(HandlerTaskDataRecord* me, Packet* packet) {
    Packet* tmp = RBObject_append(packet, me->deviceIn_);
    me->deviceIn_ = tmp;
}

static Packet* HandlerTaskDataRecord_workIn(HandlerTaskDataRecord*me) { return me->workIn_; }
static void HandlerTaskDataRecord_setWorkIn(HandlerTaskDataRecord* me, Packet* aWorkQueue) {
    me->workIn_ = aWorkQueue;
}

static void HandlerTaskDataRecord_workInAdd(HandlerTaskDataRecord* me, Packet* packet) {
    Packet* tmp = RBObject_append(packet, me->workIn_);
    me->workIn_ = tmp;
}


typedef struct IdleTaskDataRecord {
    RBObject base;
    int control;
    int count;
} IdleTaskDataRecord;

static int IdleTaskDataRecord_getControl(IdleTaskDataRecord* me) { return me->control; }
static void IdleTaskDataRecord_setControl(IdleTaskDataRecord* me, int aNumber) {
    me->control = aNumber;
}

static int IdleTaskDataRecord_getCount(IdleTaskDataRecord* me) { return me->count; }
static void IdleTaskDataRecord_setCount(IdleTaskDataRecord* me, int aCount) { me->count = aCount; }

static IdleTaskDataRecord* IdleTaskDataRecord_create() {
    IdleTaskDataRecord* me = (IdleTaskDataRecord*)malloc(sizeof(IdleTaskDataRecord));
    RBObject_init(me,0);
    me->control = 1;
    me->count = 10000;
    return me;
}

typedef struct WorkerTaskDataRecord {
    RBObject base;
    int destination;
    int count;
} WorkerTaskDataRecord;

WorkerTaskDataRecord*  WorkerTaskDataRecord_create() {
    WorkerTaskDataRecord* me = (WorkerTaskDataRecord*)malloc(sizeof(WorkerTaskDataRecord));
    RBObject_init(me,0);
    me->destination = HANDLER_A;
    me->count = 0;
    return me;
}

int WorkerTaskDataRecord_getCount(WorkerTaskDataRecord* me) { return me->count; }
void WorkerTaskDataRecord_setCount(WorkerTaskDataRecord* me, int aCount) { me->count = aCount; }

int WorkerTaskDataRecord_getDestination(WorkerTaskDataRecord* me) { return me->destination; }
void WorkerTaskDataRecord_setDestination(WorkerTaskDataRecord* me, int aHandler) { me->destination = aHandler; }

static bool TRACING = false;

typedef struct Scheduler {
    RBObject base;
    TaskControlBlock* taskList; // ref
    TaskControlBlock* currentTask; // ref
    int currentTaskIdentity;
    TaskControlBlock* taskTable[NUM_TYPES]; // ref

    int queuePacketCount;
    int holdCount;

    int layout;
} Scheduler;

static void Scheduler_init(Scheduler* me) {
    // init tracing
    me->layout  = 0;
    me->currentTask = 0;
    me->currentTaskIdentity = 0;

    // init scheduler
    me->queuePacketCount = 0;
    me->holdCount = 0;
    for(int i = 0; i < NUM_TYPES; i++ )
        me->taskTable[i] = NO_TASK;
    me->taskList = NO_TASK;
}

typedef struct FP {
   ProcessFunction base;
   Scheduler* s;
} FP;

static FP* FP_create(Scheduler* s, TaskControlBlock* (*apply)(ProcessFunction* me, Packet* work, RBObject* word))
{
    FP* me = (FP*)malloc(sizeof(FP));
    RBObject_init(me,0);
    me->s = s;
    me->base.apply = apply;
    return me;
}

static TaskControlBlock* Scheduler_holdSelf(Scheduler* me);
static TaskControlBlock* Scheduler_queuePacket(Scheduler* me, Packet* packet);
static void Scheduler_trace(Scheduler* me, int id);
static TaskControlBlock* Scheduler_markWaiting(Scheduler* me);

static TaskControlBlock* createDevice_apply(ProcessFunction* me, Packet* workArg, RBObject* wordArg)
{
    DeviceTaskDataRecord* dataRecord = (DeviceTaskDataRecord*)wordArg;
    FP* fp = me;
    Packet* functionWork = workArg; // ref
    if (NO_WORK == functionWork) {
        if (NO_WORK == (functionWork = DeviceTaskDataRecord_getPending(dataRecord))) {
            return Scheduler_markWaiting(fp->s);
        } else {
            DeviceTaskDataRecord_setPending(dataRecord,NO_WORK);
            return Scheduler_queuePacket(fp->s, functionWork);
        }
    } else {
        DeviceTaskDataRecord_setPending(dataRecord,functionWork);
        if (TRACING) {
           Scheduler_trace(fp->s, Packet_getDatum(functionWork));
        }
        return Scheduler_holdSelf(fp->s);
    }
}

static void Scheduler_createTask(Scheduler* me, int identity, int priority, Packet* work, TaskState* state,
                ProcessFunction* aBlock, RBObject* data);

static void Scheduler_createDevice(Scheduler* me, int identity, int priority, Packet* workPacket, TaskState* state) {
    DeviceTaskDataRecord* data = DeviceTaskDataRecord_create(); // ref

    FP* fp = FP_create(me, createDevice_apply); // ref
    Scheduler_createTask(me, identity, priority, workPacket, state, fp, data);
}

static TaskControlBlock* createHandler_apply(ProcessFunction* me, Packet* work, RBObject* word)
{
    HandlerTaskDataRecord* dataRecord = (HandlerTaskDataRecord*)(word);
    FP* fp = me;
    if (NO_WORK != work) {
        if (WORK_PACKET_KIND == Packet_getKind(work)) {
            HandlerTaskDataRecord_workInAdd(dataRecord, work);
        } else {
            HandlerTaskDataRecord_deviceInAdd(dataRecord, work);
        }
    }

    Packet* workPacket; // ref
    if (NO_WORK == (workPacket = HandlerTaskDataRecord_workIn(dataRecord))) {
        return Scheduler_markWaiting(fp->s);
    } else {
        int count = Packet_getDatum(workPacket);
        if (count >= DATA_SIZE) {
            HandlerTaskDataRecord_setWorkIn(dataRecord, Packet_getLink(workPacket));
            return Scheduler_queuePacket(fp->s,workPacket);
        } else {
            Packet* devicePacket; // ref
            if (NO_WORK == (devicePacket = HandlerTaskDataRecord_deviceIn(dataRecord))) {
                return Scheduler_markWaiting(fp->s);
            } else {
                HandlerTaskDataRecord_setDeviceIn(dataRecord, Packet_getLink(devicePacket));
                Packet_setDatum(devicePacket, Packet_getData(workPacket)[count]);
                Packet_setDatum(workPacket, count + 1);
                return Scheduler_queuePacket(fp->s, devicePacket);
            }
        }
    }
}

static void Scheduler_createHandler(Scheduler* me, int identity, int priority, Packet* workPaket, TaskState* state) {
    HandlerTaskDataRecord* data = HandlerTaskDataRecord_create(); // ref

    FP* fp = FP_create(me, createHandler_apply); // ref
    Scheduler_createTask(me, identity, priority, workPaket, state, fp, data);
}

static TaskControlBlock* Scheduler_release(Scheduler* me, int identity);

static TaskControlBlock* createIdler_apply(ProcessFunction* me, Packet* workArg, RBObject* wordArg)
{
    IdleTaskDataRecord* dataRecord = (IdleTaskDataRecord*)(wordArg);
    FP* fp = me;
    IdleTaskDataRecord_setCount(dataRecord, IdleTaskDataRecord_getCount(dataRecord) - 1);
    if (0 == IdleTaskDataRecord_getCount(dataRecord)) {
        return Scheduler_holdSelf(fp->s);
    } else {
        if (0 == (IdleTaskDataRecord_getControl(dataRecord) & 1)) {
            IdleTaskDataRecord_setControl(dataRecord,IdleTaskDataRecord_getControl(dataRecord) / 2);
            return Scheduler_release(fp->s, DEVICE_A);
        } else {
            IdleTaskDataRecord_setControl(dataRecord, (IdleTaskDataRecord_getControl(dataRecord) / 2) ^ 53256);
            return Scheduler_release(fp->s, DEVICE_B);
        }
    }
}

static void Scheduler_createIdler(Scheduler* me, int identity, int priority, Packet* work, TaskState* state) {

    IdleTaskDataRecord* data = IdleTaskDataRecord_create(); // ref

    FP* fp = FP_create(me, createIdler_apply); // ref
    Scheduler_createTask(me, identity, priority, work, state, fp, data);
}

static Packet* Scheduler_createPacket(Scheduler* me, Packet* link, int identity, int kind) { // ref
    return Packet_create(link, identity, kind);
}

static void Scheduler_createTask(Scheduler* me, int identity, int priority, Packet* work, TaskState* state,
                ProcessFunction* aBlock, RBObject* data) {

    TaskControlBlock* t = TaskControlBlock_create(me->taskList, identity, // ref
                                                   priority, work, state, aBlock, data);
    me->taskList = t; // t already has addRef called
    me->taskTable[identity] = t;
}

static TaskControlBlock* createWorker_apply(ProcessFunction* me, Packet* work, RBObject* word)
{
    WorkerTaskDataRecord* data = (WorkerTaskDataRecord*)(word);
    FP* fp = me;
    if (NO_WORK == work) {
        return Scheduler_markWaiting(fp->s);
    } else {
        WorkerTaskDataRecord_setDestination(
                    data, (HANDLER_A == WorkerTaskDataRecord_getDestination(data)) ?
                        HANDLER_B : HANDLER_A);
        Packet_setIdentity(work, WorkerTaskDataRecord_getDestination(data));
        Packet_setDatum(work, 0);
        for (int i = 0; i < DATA_SIZE; i++) {
            WorkerTaskDataRecord_setCount(data, WorkerTaskDataRecord_getCount(data) + 1);
            if (WorkerTaskDataRecord_getCount(data) > 26) {
                WorkerTaskDataRecord_setCount(data, 1); }
            Packet_getData(work)[i] = 65 + WorkerTaskDataRecord_getCount(data) - 1;
        }
        return Scheduler_queuePacket(fp->s, work);
    }
}

static void Scheduler_createWorker(Scheduler* me, int identity, int priority, Packet* workPaket, TaskState* state) {
    WorkerTaskDataRecord* dataRecord = WorkerTaskDataRecord_create(); // ref

    FP* fp = FP_create(me,createWorker_apply); // ref
    Scheduler_createTask(me, identity, priority, workPaket, state, fp, dataRecord);
}

static void Scheduler_schedule(Scheduler* me);

static bool Scheduler_start(Scheduler* me) {
    Packet* workQ = 0; // ref

    Scheduler_createIdler(me, IDLER, 0, NO_WORK, TaskState_createRunning());
    workQ = Scheduler_createPacket(me, NO_WORK, WORKER, WORK_PACKET_KIND);
    workQ = Scheduler_createPacket(me, workQ,   WORKER, WORK_PACKET_KIND);

    Scheduler_createWorker(me,WORKER, 1000, workQ, TaskState_createWaitingWithPacket());
    workQ = Scheduler_createPacket(me, NO_WORK, DEVICE_A, DEVICE_PACKET_KIND);
    workQ = Scheduler_createPacket(me, workQ,   DEVICE_A, DEVICE_PACKET_KIND);
    workQ = Scheduler_createPacket(me, workQ,   DEVICE_A, DEVICE_PACKET_KIND);

    Scheduler_createHandler(me, HANDLER_A, 2000, workQ, TaskState_createWaitingWithPacket());
    workQ = Scheduler_createPacket(me, NO_WORK, DEVICE_B, DEVICE_PACKET_KIND);
    workQ = Scheduler_createPacket(me, workQ, DEVICE_B, DEVICE_PACKET_KIND);
    workQ = Scheduler_createPacket(me, workQ, DEVICE_B, DEVICE_PACKET_KIND);

    Scheduler_createHandler(me, HANDLER_B, 3000, workQ, TaskState_createWaitingWithPacket());
    Scheduler_createDevice(me, DEVICE_A, 4000, NO_WORK, TaskState_createWaiting());
    Scheduler_createDevice(me, DEVICE_B, 5000, NO_WORK, TaskState_createWaiting());

    Scheduler_schedule(me);

    return me->queuePacketCount == 23246 && me->holdCount == 9297;
}

static TaskControlBlock* Scheduler_findTask(Scheduler* me, int identity) {
    TaskControlBlock* t = me->taskTable[identity];
    if (NO_TASK == t) {
        assert(0);  // "findTask failed"
    }
    return t;
}

static TaskControlBlock* Scheduler_holdSelf(Scheduler* me) {
    me->holdCount = me->holdCount + 1;
    TaskState_setTaskHolding(me->currentTask, true);
    return TaskControlBlock_getLink(me->currentTask);
}

static TaskControlBlock* Scheduler_queuePacket(Scheduler* me, Packet* packet) {
    TaskControlBlock* t = Scheduler_findTask(me, Packet_getIdentity(packet));
    if (NO_TASK == t) { return NO_TASK; }

    me->queuePacketCount = me->queuePacketCount + 1;

    Packet_setLink(packet,NO_WORK);
    Packet_setIdentity(packet,me->currentTaskIdentity);
    return TaskControlBlock_addInputAndCheckPriority(t, packet, me->currentTask);
}

static TaskControlBlock* Scheduler_release(Scheduler* me, int identity) {
    TaskControlBlock* t = Scheduler_findTask(me, identity);
    if (NO_TASK == t) { return NO_TASK; }
    TaskState_setTaskHolding(t,false);
    if (TaskControlBlock_getPriority(t) > TaskControlBlock_getPriority(me->currentTask)) {
        return t;
    } else {
        return me->currentTask;
    }
}

static void Scheduler_trace(Scheduler* me, int id) {
    me->layout = me->layout - 1;
    if (0 >= me->layout) {
        // Checkstyle: stop
        printf("\n");
        // Checkstyle: resume
        me->layout = 50;
    }
    // Checkstyle: stop
    printf("%d", id );
    // Checkstyle: resume
}

static TaskControlBlock* Scheduler_markWaiting(Scheduler* me) {
    TaskState_setTaskWaiting(me->currentTask, true);
    return me->currentTask;
}

static void Scheduler_schedule(Scheduler* me) {
    me->currentTask = me->taskList;
    while (NO_TASK != me->currentTask) {
        if (TaskState_isTaskHoldingOrWaiting(me->currentTask)) {
            TaskControlBlock* tmp = TaskControlBlock_getLink(me->currentTask);
            me->currentTask = tmp;
        } else {
            me->currentTaskIdentity = TaskControlBlock_getIdentity(me->currentTask);
            if (TRACING) { Scheduler_trace(me, me->currentTaskIdentity); }
            TaskControlBlock* tmp = TaskControlBlock_runTask(me->currentTask);
            me->currentTask = tmp;
        }
    }
}


static int benchmark(Benchmark* me)
{
    bool res = false;
    {
        Scheduler s;
        Scheduler_init(&s);
        res = Scheduler_start(&s);
    }
    RBObject_delete(toDelete);
    toDelete = 0;
    return res;
}

static bool verifyResult(Benchmark* me, int result) {
    return result != 0;
}


Benchmark*Richards_create()
{
    Benchmark* bench = (Benchmark*)malloc(sizeof(Benchmark));
    bench->benchmark = benchmark;
    bench->verifyResult = verifyResult;
    bench->dispose = 0;
    bench->innerBenchmarkLoop = 0;
    return bench;
}
