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

unit List;
interface
uses Benchmark;

type
	PList = ^TList;
	TList = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		end;
		
implementation

type
	ElemPtr = ^Element;
	Element = object
			constructor init(v: longint);
			destructor deinit();
			procedure setNext(ptr: ElemPtr);
			function getNext():ElemPtr;
			function length():longint;
		private
			val, refCount: longint;
			next: ElemPtr;
		end;

	procedure addRef(ptr: ElemPtr);
	begin
		if ptr = nil then exit;
		ptr^.refCount += 1;
	end;
	
	procedure release(ptr: ElemPtr);
	begin
		if ptr = nil then exit;
		ptr^.refCount -= 1;
		if ptr^.refCount <= 0 then dispose(ptr,deinit);
	end;

	constructor Element.init(v: longint);
	begin
		val := v;
		refCount := 0;
	end;
	
	destructor Element.deinit();
	begin
		release(next);
	end;
	
	function Element.length():longint;
	begin
        if next = nil then begin exit(1); end
        else exit(1 + next^.length());
	end;
	
	procedure Element.setNext(ptr: ElemPtr);
	begin
		release(next);
		next := ptr;
		addRef(next);
	end;
	
	function Element.getNext():ElemPtr;
	begin
		exit(next);
	end;
	
    constructor TList.init;
    begin
    	inherited init;
    end;
    
    destructor TList.deinit;
    begin
    	inherited deinit;
    end;

	function makeList(length: longint):ElemPtr;
	var e: ElemPtr;
	begin
		if length = 0 then exit(nil);
		new(e);
		e^.init(length);
		e^.setNext(makeList(length-1));
		exit(e);
	end;
	
	function isShorterThan(x,y: ElemPtr):boolean;
	var xTail, yTail: ElemPtr;
	begin
		xTail := x;
		yTail := y;
		while yTail <> nil do
		begin
		    if xTail = nil then exit(true);
		    xTail := xTail^.getNext();
		    yTail := yTail^.getNext();
		end;
		exit(false);
	end;
	
	function tail(x, y, z: ElemPtr):ElemPtr;
	begin
		if isShorterThan(y, x) then
		begin
		    exit(tail(tail(x^.getNext(), y, z),
		                tail(y^.getNext(), z, x),
		                tail(z^.getNext(), x, y)));
		end
		else 
		    exit(z);
	end;

    function TList.benchmark(): longint;
    var x, y, z, result: ElemPtr;
    begin
    	x := makeList(15);
    	addRef(x);
    	y := makeList(10);
    	addRef(y);
    	z := makeList(6);
    	addRef(z);
    	result := tail(x,y,z);
    	addRef(result);
    	release(x);
    	release(y);
    	release(z);
    	benchmark := result^.length();
    	release(result);
    end;
    
    function TList.verifyResult(result: longint): boolean;
    begin
    	exit(10 = result);
    end;
    
end.
