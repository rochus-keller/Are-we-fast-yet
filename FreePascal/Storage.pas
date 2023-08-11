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
 
unit Storage;
interface
uses Benchmark;

type
	PStorage = ^TStorage;
	TStorage = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		end;
		
implementation
	uses Random;
	
	type 
		TreePtr = ^Tree;
		TreeList = array of TreePtr;
		Tree = object 
					sub: TreeList; 
					constructor init;
					destructor deinit; 
			   end;
	var
		count: longint;
		
	constructor Tree.init;
	begin
	end;
	
	destructor Tree.deinit;
	var i: longint;
	begin
		for i := 0 to length(sub)-1 do
			dispose(sub[i],deinit);
	end;
	
    constructor TStorage.init;
    begin
    	inherited init;
    end;
    
    destructor TStorage.deinit;
    begin
    	inherited deinit;
    end;
    
    procedure buildTreeDepth(depth: longint; var t: TreeList);
    var len, i: longint;
    begin
		count += 1;
		if depth = 1 then
			begin
				len := Random_next() mod 10 + 1;
				setLength(t,len);
				for i := 0 to len-1 do
					new(t[i],init);
			end 
		else 
			begin
				len := 4;
				setLength(t,len);
				for i := 0 to len-1 do
				begin
					new(t[i],init);
				    buildTreeDepth(depth - 1, t[i]^.sub);
				end;
			end;
    end;
    
    function TStorage.benchmark(): longint; 
    var t: Tree;
    begin
        Random_reset();
    	count := 0;
    	t.init();
    	buildTreeDepth(7, t.sub);
    	t.deinit();
    	exit(count);
    end;
    
    function TStorage.verifyResult(result: longint): boolean;
    begin
    	exit(5461 = result);
    end;

end.
