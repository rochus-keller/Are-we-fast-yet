QUEENS ; Queens benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 Q
BENCH ;
 S RSLT=1
 F I=1:1:10 D QRUN
 Q
QRUN ; one SOLVE; clears RSLT on failure
 D SOLVE
 I 'OK2 S RSLT=0
 Q
SOLVE ; empty board, then place from column 1; result -> OK2
 K FREER,FREEMX,FREEMN,QUEENR,ST
 F R0=1:1:8 S FREER(R0)=1,QUEENR(R0)=-1
 F R0=1:1:16 S FREEMX(R0)=1,FREEMN(R0)=1
 S SP=0
 S PC=1 D PLACE
 S OK2=PFOUND
 Q
PLACE ; place a queen in column PC; result -> PFOUND
 S SP=SP+1
 S ST(SP,"c")=PC
 S ST(SP,"f")=0
 F ST(SP,"r")=1:1:8 D PTRY Q:ST(SP,"f")
 S PFOUND=ST(SP,"f")
 S SP=SP-1
 Q
PTRY ; try row ST(SP,"r") in column ST(SP,"c")
 S C=ST(SP,"c"),R=ST(SP,"r")
 Q:'FREER(R)
 Q:'FREEMX(C+R)
 Q:'FREEMN(C-R+8)
 S QUEENR(R)=C
 S FREER(R)=0,FREEMX(C+R)=0,FREEMN(C-R+8)=0
 I C=8 S ST(SP,"f")=1 Q
 S PC=C+1 D PLACE
 S C=ST(SP,"c"),R=ST(SP,"r")
 I PFOUND S ST(SP,"f")=1 Q
 S FREER(R)=1,FREEMX(C+R)=1,FREEMN(C-R+8)=1
 Q
VERIFY ;
 S OK=RSLT=1
 Q
