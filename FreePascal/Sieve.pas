(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch> (for FreePascal migration)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the 'Software'), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *)
 
unit Sieve;
interface
uses Benchmark;

type
	PSieve = ^TSieve;
	TSieve = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		end;
		
implementation

    constructor TSieve.init;
    begin
    	inherited init;
    end;
    
    destructor TSieve.deinit;
    begin
    	inherited deinit;
    end;
 
 	function sieve(var flags: array of boolean; size: longint): longint;
    	var primeCount, i, k: longint;
    begin
        primeCount := 0;

    	for i := 2 to size do
    	begin
		    if flags[i - 1] then
		    begin
		        primeCount += 1;
		        k := i + i;
		        while k <= size do
		        begin
		            flags[k - 1] := false;
		            k += i;
		        end;
		    end;
		end;
    	exit(primeCount);
	end;
	
    function TSieve.benchmark(): longint; 
    	const count = 5000;
    	var flags: array [0..count-1] of boolean; i: longint;
    begin
		for i := 0 to count-1 do
		    flags[i] := true;
		exit(sieve(flags, count));
    end;
    
    function TSieve.verifyResult(result: longint): boolean; 
    begin
    	exit(669 = result);
    end;
   
end.
