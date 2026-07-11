RICHARDS ; Richards task-scheduler benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 Q
 ; 0 denotes NO_WORK / NO_TASK; packet ids are >=1, task ids are 1..6.
 ; IDLER=1 WORKER=2 HANDLER_A=3 HANDLER_B=4 DEVICE_A=5 DEVICE_B=6
 ; fn tags: 1=idle 2=worker 3=handler 4=device
 ; packet kinds: DEVICE=0  WORK=1 ; DATA_SIZE=4
BENCH ;
 K TCB,TT,PKT,IDR,WDR,HDR,DDR
 S TASKL=0,CT=0,CTI=0,QCNT=0,HCNT=0,PID=0
 D START
 D SCHED
 S RSLT=(QCNT=23246)&(HCNT=9297)
 Q
VERIFY ;
 S OK=RSLT
 Q
START ;
 ; idler: create_running (pp=0,tw=0,th=0)
 S IDR(1,"control")=1,IDR(1,"count")=10000
 S MKID=1,MKPRI=0,MKWRK=0,MKPP=0,MKTW=0,MKTH=0,MKFN=1 D CMKTASK
 ; two work packets for the worker
 S CLINK=0,CIDENT=2,CKIND=1 D CPKT S Q1=CRES
 S CLINK=Q1,CIDENT=2,CKIND=1 D CPKT S Q1=CRES
 ; worker: create_waiting_with_packet (pp=1,tw=1,th=0)
 S WDR(2,"destination")=3,WDR(2,"count")=0
 S MKID=2,MKPRI=1000,MKWRK=Q1,MKPP=1,MKTW=1,MKTH=0,MKFN=2 D CMKTASK
 ; three device packets destined to DEVICE_A for handler A
 S CLINK=0,CIDENT=5,CKIND=0 D CPKT S Q1=CRES
 S CLINK=Q1,CIDENT=5,CKIND=0 D CPKT S Q1=CRES
 S CLINK=Q1,CIDENT=5,CKIND=0 D CPKT S Q1=CRES
 S HDR(3,"work_in")=0,HDR(3,"device_in")=0
 S MKID=3,MKPRI=2000,MKWRK=Q1,MKPP=1,MKTW=1,MKTH=0,MKFN=3 D CMKTASK
 ; three device packets destined to DEVICE_B for handler B
 S CLINK=0,CIDENT=6,CKIND=0 D CPKT S Q1=CRES
 S CLINK=Q1,CIDENT=6,CKIND=0 D CPKT S Q1=CRES
 S CLINK=Q1,CIDENT=6,CKIND=0 D CPKT S Q1=CRES
 S HDR(4,"work_in")=0,HDR(4,"device_in")=0
 S MKID=4,MKPRI=3000,MKWRK=Q1,MKPP=1,MKTW=1,MKTH=0,MKFN=3 D CMKTASK
 ; devices: create_waiting (pp=0,tw=1,th=0)
 S DDR(5,"pending")=0
 S MKID=5,MKPRI=4000,MKWRK=0,MKPP=0,MKTW=1,MKTH=0,MKFN=4 D CMKTASK
 S DDR(6,"pending")=0
 S MKID=6,MKPRI=5000,MKWRK=0,MKPP=0,MKTW=1,MKTH=0,MKFN=4 D CMKTASK
 Q
CMKTASK ; create_task: insert TCB at head of task_list, register in TT
 S TCB(MKID,"link")=TASKL
 S TCB(MKID,"identity")=MKID
 S TCB(MKID,"priority")=MKPRI
 S TCB(MKID,"input")=MKWRK
 S TCB(MKID,"handle")=MKID
 S TCB(MKID,"pp")=MKPP,TCB(MKID,"tw")=MKTW,TCB(MKID,"th")=MKTH
 S TCB(MKID,"fn")=MKFN
 S TASKL=MKID
 S TT(MKID)=MKID
 Q
CPKT ; create_packet(CLINK,CIDENT,CKIND) -> CRES
 S PID=PID+1
 S PKT(PID,"link")=CLINK,PKT(PID,"kind")=CKIND,PKT(PID,"identity")=CIDENT
 S PKT(PID,"datum")=1
 S PKT(PID,"data",1)=0,PKT(PID,"data",2)=0,PKT(PID,"data",3)=0,PKT(PID,"data",4)=0
 S CRES=PID
 Q
SCHED ; scheduler loop
 S CT=TASKL
 F SI=0:1 Q:CT=0  D SCHED1
 Q
SCHED1 ; is_task_holding_or_waiting -> skip; else run
 I TCB(CT,"th")!('TCB(CT,"pp")&TCB(CT,"tw")) S CT=TCB(CT,"link") Q
 S CTI=TCB(CT,"identity")
 D RUNTASK
 S CT=NEXT
 Q
RUNTASK ; TaskControlBlock:run_task
 S MSG=0
 I TCB(CT,"pp"),TCB(CT,"tw"),'TCB(CT,"th") D RUNT1
 S FN=TCB(CT,"fn"),HANDLE=TCB(CT,"handle")
 D RUNFN
 Q
RUNT1 ; waiting_with_packet: dequeue the head input packet
 S MSG=TCB(CT,"input")
 S TCB(CT,"input")=PKT(MSG,"link")
 I TCB(CT,"input")=0 S TCB(CT,"pp")=0,TCB(CT,"tw")=0,TCB(CT,"th")=0 Q
 S TCB(CT,"pp")=1,TCB(CT,"tw")=0,TCB(CT,"th")=0
 Q
RUNFN ; simulated function pointer: dispatch on the task-type tag
 I FN=1 D FIDLE Q
 I FN=2 D FWORK Q
 I FN=3 D FHAND Q
 D FDEV
 Q
FIDLE ; idle task; ignores MSG; HANDLE keys IDR
 S H=HANDLE
 S IDR(H,"count")=IDR(H,"count")-1
 I IDR(H,"count")=0 D SHOLD Q
 I IDR(H,"control")#2=0 S IDR(H,"control")=IDR(H,"control")\2,RLID=5 D SREL Q
 S XA=(IDR(H,"control")-1)\2,XB=53256 D XOR S IDR(H,"control")=XR
 S RLID=6 D SREL
 Q
FWORK ; worker task: fill a packet and queue it to a handler
 I MSG=0 D SWAIT Q
 S H=HANDLE
 I WDR(H,"destination")=3 S WDR(H,"destination")=4
 E  S WDR(H,"destination")=3
 S PKT(MSG,"identity")=WDR(H,"destination"),PKT(MSG,"datum")=1
 F WI=1:1:4 D FWORK1
 S QPKT=MSG D SQUEUE
 Q
FWORK1 ; one payload byte (A..Z cycling)
 S WDR(H,"count")=WDR(H,"count")+1
 I WDR(H,"count")>26 S WDR(H,"count")=1
 S PKT(MSG,"data",WI)=65+WDR(H,"count")-1
 Q
FHAND ; handler task: pair work packets with device packets
 I MSG'=0 D FHAND0
 S H=HANDLE
 S WP=HDR(H,"work_in")
 I WP=0 D SWAIT Q
 S CNT=PKT(WP,"datum")
 I CNT>4 S HDR(H,"work_in")=PKT(WP,"link"),QPKT=WP D SQUEUE Q
 S DP=HDR(H,"device_in")
 I DP=0 D SWAIT Q
 S HDR(H,"device_in")=PKT(DP,"link")
 S PKT(DP,"datum")=PKT(WP,"data",CNT)
 S PKT(WP,"datum")=CNT+1
 S QPKT=DP D SQUEUE
 Q
FHAND0 ; enqueue incoming packet by kind
 S H=HANDLE
 I PKT(MSG,"kind")=1 S APKT=MSG,AQH=HDR(H,"work_in") D APPEND S HDR(H,"work_in")=ARES Q
 S APKT=MSG,AQH=HDR(H,"device_in") D APPEND S HDR(H,"device_in")=ARES
 Q
FDEV ; device task: hold a packet, then re-queue it next time
 S H=HANDLE
 I MSG=0 D FDEV0 Q
 S DDR(H,"pending")=MSG
 D SHOLD
 Q
FDEV0 ;
 S DPK=DDR(H,"pending")
 I DPK=0 D SWAIT Q
 S DDR(H,"pending")=0,QPKT=DPK D SQUEUE
 Q
SWAIT ; Scheduler:wait
 S TCB(CT,"tw")=1
 S NEXT=CT
 Q
SHOLD ; Scheduler:hold_self
 S HCNT=HCNT+1
 S TCB(CT,"th")=1
 S NEXT=TCB(CT,"link")
 Q
SREL ; Scheduler:release(RLID)
 S FTID=RLID D SFIND S RT=FTRES
 I RT=0 S NEXT=0 Q
 S TCB(RT,"th")=0
 I TCB(RT,"priority")>TCB(CT,"priority") S NEXT=RT Q
 S NEXT=CT
 Q
SQUEUE ; Scheduler:queue_packet(QPKT)
 S FTID=PKT(QPKT,"identity") D SFIND S QT=FTRES
 I QT=0 S NEXT=0 Q
 S QCNT=QCNT+1
 S PKT(QPKT,"link")=0,PKT(QPKT,"identity")=CTI
 S AITASK=QT,AIPKT=QPKT,AIOLD=CT D SADDIN
 Q
SFIND ; Scheduler:find_task(FTID) -> FTRES
 S FTRES=TT(FTID)
 Q
SADDIN ; TaskControlBlock:add_input_and_check_priority
 I TCB(AITASK,"input")=0 D SADDIN1 Q
 S APKT=AIPKT,AQH=TCB(AITASK,"input") D APPEND S TCB(AITASK,"input")=ARES
 S NEXT=AIOLD
 Q
SADDIN1 ; input queue was empty
 S TCB(AITASK,"input")=AIPKT,TCB(AITASK,"pp")=1
 I TCB(AITASK,"priority")>TCB(AIOLD,"priority") S NEXT=AITASK Q
 S NEXT=AIOLD
 Q
APPEND ; RBObject:append(APKT, AQH) -> ARES (append packet at queue tail)
 S PKT(APKT,"link")=0
 I AQH=0 S ARES=APKT Q
 S AMOUSE=AQH,ALINK=PKT(AMOUSE,"link")
 F AI=0:1 Q:ALINK=0  S AMOUSE=ALINK,ALINK=PKT(AMOUSE,"link")
 S PKT(AMOUSE,"link")=APKT
 S ARES=AQH
 Q
XOR ; XR = XA xor XB for non-negative integers
 S XR=0,XBIT=1
 F XI=1:1 Q:(XA=0)&(XB=0)  D XORB
 Q
XORB ;
 S XVA=XA#2,XVB=XB#2
 I XVA'=XVB S XR=XR+XBIT
 S XA=XA\2,XB=XB\2,XBIT=XBIT*2
 Q
