PERMUTE ; Permute benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 Q
BENCH ;
 K ST,V
 S COUNT=0,SP=0
 F I=1:1:6 S V(I)=0
 S N=6 D PERM
 S RSLT=COUNT
 Q
PERM ; recursive permutation counter for prefix length N
 S SP=SP+1
 S ST(SP,"n")=N
 S COUNT=COUNT+1
 I ST(SP,"n")=0 S SP=SP-1 Q
 S N=ST(SP,"n")-1 D PERM
 F ST(SP,"i")=ST(SP,"n"):-1:1 D PSWAP
 S SP=SP-1
 Q
PSWAP ; swap v(n),v(i); recurse on n-1; swap back
 S TMP=V(ST(SP,"n")),V(ST(SP,"n"))=V(ST(SP,"i")),V(ST(SP,"i"))=TMP
 S N=ST(SP,"n")-1 D PERM
 S TMP=V(ST(SP,"n")),V(ST(SP,"n"))=V(ST(SP,"i")),V(ST(SP,"i"))=TMP
 Q
VERIFY ;
 S OK=RSLT=8660
 Q
