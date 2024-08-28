# Author: Rochus Keller, 2024

flags=" -w " 

for t in som/*.c
do
    echo "compiling $t"
    ./compiler $(readlink -m $t) $flags -c -I/home/me/Entwicklung/Modules/EiGen/ecc/include
done

for t in *.c
do
    echo "compiling $t"
    ./compiler $(readlink -m $t) $flags -c -I/home/me/Entwicklung/Modules/EiGen/ecc/include
done

./compiler *.obf $flags libc.lib -L/home/me/Entwicklung/Modules/EiGen/runtime 
