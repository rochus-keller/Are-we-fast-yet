STORAGE ; Storage benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 ; this actually allocates a tree of records in ARR
 Q
BENCH ;
 K ST,ARR
 S SEED=74755,COUNT=0,NID=0,SP=0
 S DEPTH=7 D BUILD
 S RSLT=COUNT
 Q
BUILD ; build a subtree of DEPTH, allocate its node -> BRES (node id)
 S SP=SP+1
 S ST(SP,"d")=DEPTH
 S COUNT=COUNT+1
 I ST(SP,"d")=1 D BLEAF S BRES=ST(SP,"id") S SP=SP-1 Q
 S NID=NID+1,ST(SP,"id")=NID
 S ARR(ST(SP,"id"),"n")=4
 F ST(SP,"i")=1:1:4 D BCHILD
 S BRES=ST(SP,"id")
 S SP=SP-1
 Q
BLEAF ; allocate a leaf whose size comes from the RNG stream
 S SEED=((SEED*1309)+13849)#65536
 S NID=NID+1,ST(SP,"id")=NID
 S ARR(ST(SP,"id"),"n")=(SEED#10)+1
 Q
BCHILD ; build one child and store its id in the parent record
 S DEPTH=ST(SP,"d")-1 D BUILD
 S ARR(ST(SP,"id"),ST(SP,"i"))=BRES
 Q
VERIFY ;
 S OK=RSLT=5461
 Q
