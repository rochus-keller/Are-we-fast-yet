LIST ; List benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 ; array-based linked list in NODES; NEXTID is the id allocator
 Q
BENCH ;
 K NODES,MK,T
 S NEXTID=0,MKSP=0,TLSP=0
 S MKLEN=15 D MKLIST S L1=MKRES
 S MKLEN=10 D MKLIST S L2=MKRES
 S MKLEN=6 D MKLIST S L3=MKRES
 S TLX=L1,TLY=L2,TLZ=L3 D TAIL S RESULT=TLRES
 S LNID=RESULT D LEN
 S RSLT=LNRES
 Q
MKLIST ; build a list of MKLEN elements (values MKLEN..1) -> MKRES
 S MKSP=MKSP+1
 S MK(MKSP,"l")=MKLEN
 I MK(MKSP,"l")=0 S MKRES="" S MKSP=MKSP-1 Q
 S NEXTID=NEXTID+1,MK(MKSP,"e")=NEXTID
 S NODES(MK(MKSP,"e"),"val")=MK(MKSP,"l")
 S MKLEN=MK(MKSP,"l")-1 D MKLIST
 S NODES(MK(MKSP,"e"),"next")=MKRES
 S MKRES=MK(MKSP,"e")
 S MKSP=MKSP-1
 Q
LEN ; length of list LNID -> LNRES
 I LNID="" S LNRES=0 Q
 S LNID=NODES(LNID,"next") D LEN
 S LNRES=1+LNRES
 Q
SHORTER ; is list SHX shorter than list SHY? -> SHRES
 S SHXT=SHX,SHYT=SHY,SHRES=0
 F SHK=0:1 Q:SHYT=""  S:SHXT="" SHRES=1 Q:SHRES  S SHXT=NODES(SHXT,"next"),SHYT=NODES(SHYT,"next")
 Q
TAIL ; the AWFY three-way list recursion -> TLRES
 S TLSP=TLSP+1
 S T(TLSP,"x")=TLX,T(TLSP,"y")=TLY,T(TLSP,"z")=TLZ
 S SHX=T(TLSP,"y"),SHY=T(TLSP,"x") D SHORTER
 I 'SHRES S TLRES=T(TLSP,"z") S TLSP=TLSP-1 Q
 S T(TLSP,"nx")=$S(T(TLSP,"x")="":"",1:NODES(T(TLSP,"x"),"next"))
 S T(TLSP,"ny")=$S(T(TLSP,"y")="":"",1:NODES(T(TLSP,"y"),"next"))
 S T(TLSP,"nz")=$S(T(TLSP,"z")="":"",1:NODES(T(TLSP,"z"),"next"))
 S TLX=T(TLSP,"nx"),TLY=T(TLSP,"y"),TLZ=T(TLSP,"z") D TAIL
 S T(TLSP,"t1")=TLRES
 S TLX=T(TLSP,"ny"),TLY=T(TLSP,"z"),TLZ=T(TLSP,"x") D TAIL
 S T(TLSP,"t2")=TLRES
 S TLX=T(TLSP,"nz"),TLY=T(TLSP,"x"),TLZ=T(TLSP,"y") D TAIL
 S T(TLSP,"t3")=TLRES
 S TLX=T(TLSP,"t1"),TLY=T(TLSP,"t2"),TLZ=T(TLSP,"t3") D TAIL
 S TLSP=TLSP-1
 Q
VERIFY ;
 S OK=RSLT=10
 Q
