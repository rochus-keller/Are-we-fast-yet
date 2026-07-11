TOWERS ; Towers of Hanoi benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 Q
BENCH ;
 K PILES,ST
 S MOVES=0,SP=0
 F I=13:-1:1 S PSIZE=I,PPILE=1 D PUSH
 S MDISKS=13,MFROM=1,MTO=2 D MOVE
 S RSLT=MOVES
 Q
PUSH ; push disk PSIZE onto pile PPILE
 S PTOP=$S($D(PILES(PPILE,"top"))#10:PILES(PPILE,"top"),1:"")
 I PTOP'="" I PSIZE'<PTOP W "Cannot put big disk on smaller",! Q
 S PILES(PPILE,"d",PSIZE)=PTOP
 S PILES(PPILE,"top")=PSIZE
 Q
POP ; pop the top disk of pile OPILE -> OTOP
 S OTOP=PILES(OPILE,"top")
 S ONEXT=$S($D(PILES(OPILE,"d",OTOP))#10:PILES(OPILE,"d",OTOP),1:"")
 I ONEXT="" K PILES(OPILE,"top")
 E  S PILES(OPILE,"top")=ONEXT
 K PILES(OPILE,"d",OTOP)
 Q
MOVETOP ; move one disk from pile MTFR to pile MTTO
 S OPILE=MTFR D POP
 S PSIZE=OTOP,PPILE=MTTO D PUSH
 S MOVES=MOVES+1
 Q
MOVE ; recursively move MDISKS disks from MFROM to MTO
 S SP=SP+1
 S ST(SP,"n")=MDISKS,ST(SP,"f")=MFROM,ST(SP,"t")=MTO
 I ST(SP,"n")=1 S MTFR=ST(SP,"f"),MTTO=ST(SP,"t") D MOVETOP S SP=SP-1 Q
 S ST(SP,"o")=6-ST(SP,"f")-ST(SP,"t")
 S MDISKS=ST(SP,"n")-1,MFROM=ST(SP,"f"),MTO=ST(SP,"o") D MOVE
 S MTFR=ST(SP,"f"),MTTO=ST(SP,"t") D MOVETOP
 S MDISKS=ST(SP,"n")-1,MFROM=ST(SP,"o"),MTO=ST(SP,"t") D MOVE
 S SP=SP-1
 Q
VERIFY ;
 S OK=RSLT=8191
 Q
