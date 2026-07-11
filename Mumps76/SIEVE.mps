SIEVE ; Sieve of Eratosthenes benchmark (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 Q
BENCH ;
 K FLAGS
 F I=1:1:5000 S FLAGS(I)=1
 S PRIMEC=0
 F I=2:1:5000 D MARK
 S RSLT=PRIMEC
 Q
MARK ; count prime at I-1 (if still flagged) and strike its multiples
 I 'FLAGS(I-1) Q
 S PRIMEC=PRIMEC+1
 F K=I+I:I:5000 S FLAGS(K-1)=0
 Q
VERIFY ;
 S OK=RSLT=669
 Q
