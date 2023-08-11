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

unit Permute;
interface
uses Benchmark;

const len = 6;

type
	PPermute = ^TPermute;
	TPermute = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		private
			count: longint;
			v: array [0..len-1] of longint;
		    procedure swap(i,j: longint);
		    procedure permute(n: longint);
		end;
		
implementation

    constructor TPermute.init;
    begin
    	inherited init;
    end;
    
    destructor TPermute.deinit;
    begin
    	inherited deinit;
    end;
    
    procedure TPermute.swap(i,j: longint);
    var tmp: longint;
    begin
    	tmp := v[i];
    	v[i] := v[j];
    	v[j] := tmp;
	end;

    procedure TPermute.permute(n: longint);
    var n1, i: longint;
    begin
    	count += 1;
    	if n <> 0 then
    	begin
        	n1 := n - 1;
        	permute(n1);
        	for i := n1 downto 0 do
        	begin
            	swap(n1, i);
            	permute(n1);
            	swap(n1, i);
            end;
        end;
    end;

    function TPermute.benchmark(): longint;
    begin
        count := 0;
    	permute(len);
    	exit(count);
    end;
    
    function TPermute.verifyResult(result: longint): boolean;
    begin
    	exit(result = 8660);
    end;
    

end.
