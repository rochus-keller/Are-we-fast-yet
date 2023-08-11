(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch> (for FreePascal migration)
 *
// Copyright (C) 2004-2013 Brent Fulgham
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//   * Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * Neither the name of "The Computer Language Benchmarks Game" nor the name
//     of "The Computer Language Shootout Benchmarks" nor the names of its
//     contributors may be used to endorse or promote products derived from this
//     software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// The Computer Language Benchmarks Game
// http://benchmarksgame.alioth.debian.org
//
//  contributed by Karl von Laudermann
//  modified by Jeremy Echols
//  modified by Detlef Reichl
//  modified by Joseph LaFata
//  modified by Peter Zotov
*)

unit Mandelbrot;
interface
uses Benchmark;

type
	PMandelbrot = ^TMandelbrot;
	TMandelbrot = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		    function innerBenchmarkLoop(innerIterations: longint): boolean; virtual;
		end;
		
implementation

    constructor TMandelbrot.init;
    begin
    	inherited init;
    end;
    
    destructor TMandelbrot.deinit;
    begin
    	inherited deinit;
    end;

	function mandelbrot(size: longint):longint;
	var sum, byteAcc, bitNum, x, y, z, escape: longint;	
		ci, zr, zrzr, zi, zizi, cr: double;
		notDone: boolean;
	begin
   		sum     := 0;
    	byteAcc := 0;
    	bitNum  := 0;

    	y := 0;

		while y < size do
		begin
		    ci := (2.0 * y / size) - 1.0;
		    x := 0;

		    while x < size do
		    begin
		        zr   := 0.0;
		        zrzr := 0.0;
		        zi   := 0.0;
		        zizi := 0.0;
		        cr := (2.0 * x / size) - 1.5;

		        z := 0;
		        notDone := true;
		        escape := 0;
		        while notDone and (z < 50) do
		        begin
		            zr := zrzr - zizi + cr;
		            zi := 2.0 * zr * zi + ci;

		            // preserve recalculation
		            zrzr := zr * zr;
		            zizi := zi * zi;

		            if zrzr + zizi > 4.0 then
		            begin
		                notDone := false;
		                escape  := 1;
		            end;
		            z += 1;
		        end;

		        byteAcc := (byteAcc << 1) + escape;
		        bitNum += 1;

		        // Code is very similar for these cases, but using separate blocks
		        // ensures we skip the shifting when it's unnecessary, which is most cases.
		        if bitNum = 8 then
		        begin
		            sum := sum xor byteAcc;
		            byteAcc := 0;
		            bitNum  := 0;
		        end else if x = size - 1 then
		        begin
		            byteAcc := byteAcc << (8 - bitNum);
		            sum := sum xor byteAcc;
		            byteAcc := 0;
		            bitNum  := 0;
		        end;
		        x += 1;
		    end;
		    y += 1;
		end;
    	exit(sum);
	end;
	
	function verifyResult2(result, innerIterations: longint):boolean;
	begin
		if innerIterations = 500 then exit(result = 191);
		if innerIterations = 750 then exit(result = 50);
		if innerIterations = 1 then exit(result = 128);

		// Checkstyle: stop
		Write('No verification result for ');
		Write(innerIterations);
		WriteLn(' found');
		Write('Result is: ');
		WriteLn(result);
		// Checkstyle: resume
		exit(false);
	end;

    function TMandelbrot.benchmark(): longint;
    begin
    	halt;
    	exit(0);
    end;
    
    function TMandelbrot.verifyResult(result: longint): boolean;
    begin
    	halt;
    	exit(false);
    end;
    
    function TMandelbrot.innerBenchmarkLoop(innerIterations: longint): boolean; 
    begin
    	exit(verifyResult2(mandelbrot(innerIterations), innerIterations));
   end;

end.
