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

unit Bounce;
interface
uses Benchmark;

type
	PBounce = ^TBounce;
	TBounce = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		end;
		
implementation
	uses Random;
	
type
	Ball = object
        	x, y, xVel, yVel: longint;
        	constructor init;
        	function bounce():boolean;
        	end;
    
    constructor Ball.init;
    begin
        x := Random_next() mod 500;
        y := Random_next() mod 500;
        xVel := (Random_next() mod 300) - 150;
        yVel := (Random_next() mod 300) - 150;
    end;
    
    function Ball.bounce():boolean;
    const xLimit = 500; yLimit = 500;
    var bounced : boolean;
    begin
    	bounced := false;
		x += xVel;
		y += yVel;
		if x > xLimit then begin x := xLimit; xVel := 0 - abs(xVel); bounced := true; end;
		if x < 0 then begin x := 0; xVel := abs(xVel); bounced := true; end;
		if y > yLimit then begin y := yLimit; yVel := 0 - abs(yVel); bounced := true; end;
		if y < 0 then begin y := 0; yVel := abs(yVel); bounced := true; end;
		exit(bounced);
    end;
    
    constructor TBounce.init;
    begin
    	inherited init;
    end;
    
    destructor TBounce.deinit;
    begin
    	inherited deinit;
    end;


    function TBounce.benchmark(): longint;
    const ballCount = 100;
    var bounces, i, j: longint;
    	balls: array [0..ballCount-1] of Ball;
    begin
		Random_reset();
		bounces   := 0;
		
		for j := 0 to ballCount-1 do
			balls[j].init();
			
		for i := 0 to 49 do
			for j := 0 to ballCount-1 do
				if balls[j].bounce() then
				    bounces += 1;
    	exit(bounces);
    end;
    
    function TBounce.verifyResult(result: longint): boolean;
    begin
    	exit(result = 1331);
    end;
    
end.
