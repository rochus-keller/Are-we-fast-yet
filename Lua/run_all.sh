SOM=./lua


#this is the original order from rebench.conf; the iteration count is original up to Havlak which is 1500 in the original
Benchmarks=( DeltaBlue Richards Json Havlak CD	Bounce List Mandelbrot NBody  Permute Queens Sieve Storage Towers )
Iterations=( 12000     100      100  10     250	1500   1500 500        250000 1000    1000   3000  1000    600     )

for i in "${!Benchmarks[@]}"
do
	echo "running" ${Benchmarks[i]} "with" ${Iterations[i]} "iterations"
	$SOM harness.lua ${Benchmarks[i]} ${Iterations[i]} 
done


