HARNESS ; Benchmark harness (strict MUMPS NBS-118 1976)
 ; migrated by me@rochus-keller.ch, see also AUTHORS.md file
 ; the benchmark name is passed in BM, iteration count in NI
 ; each benchmark leaves its answer in RSLT and its pass/fail in OK
 ; timing uses $ZHOROLOG, the GT.M / YottaDB microsecond clock
 S BM="Sieve",NI=100 D RUN
 S BM="Bounce",NI=100 D RUN
 S BM="Permute",NI=100 D RUN
 S BM="Queens",NI=100 D RUN
 S BM="Towers",NI=100 D RUN
 S BM="Storage",NI=100 D RUN
 S BM="List",NI=100 D RUN
 S BM="Mandelbrot",NI=100 D RUN
 S BM="Richards",NI=100 D RUN
 Q
RUN ; run BM for NI iterations, time and verify
 W "Starting ",BM," benchmark ...",!
 S T1=$ZHOROLOG,FAIL=0
 F HI=1:1:NI D ONCE Q:FAIL
 S T2=$ZHOROLOG
 I FAIL W BM,": FAILED verification",! Q
 S DD=$P(T2,",",1)-$P(T1,",",1)
 S SS=$P(T2,",",2)-$P(T1,",",2)
 S UU=$P(T2,",",3)-$P(T1,",",3)
 S TOT=(((DD*86400)+SS)*1000000)+UU
 S AVG=(TOT+(NI\2))\NI
 W BM,": iterations=",NI," average: ",AVG,"us total: ",TOT,"us",!
 Q
ONCE ; one run of BM plus verification
 D DISP
 I 'OK S FAIL=1
 Q
DISP ; dispatch: run BENCH then VERIFY for the selected benchmark
 I BM="Sieve" D BENCH^SIEVE,VERIFY^SIEVE Q
 I BM="Bounce" D BENCH^BOUNCE,VERIFY^BOUNCE Q
 I BM="Permute" D BENCH^PERMUTE,VERIFY^PERMUTE Q
 I BM="Queens" D BENCH^QUEENS,VERIFY^QUEENS Q
 I BM="Towers" D BENCH^TOWERS,VERIFY^TOWERS Q
 I BM="Storage" D BENCH^STORAGE,VERIFY^STORAGE Q
 I BM="List" D BENCH^LIST,VERIFY^LIST Q
 I BM="Mandelbrot" S SIZE=1 D BENCH^MANDEL,VERIFY^MANDEL Q
 I BM="Richards" D BENCH^RICHARDS,VERIFY^RICHARDS Q
 W "Unknown benchmark: ",BM,!
 S OK=0
 Q
