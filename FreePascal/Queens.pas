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

unit Queens;
interface
uses Benchmark;

const len = 8;

type
	PQueens = ^TQueens;
	TQueens = object(TBenchmark)
		    constructor init;
		    destructor deinit; virtual;
		    function benchmark(): longint; virtual;
		    function verifyResult(result: longint): boolean; virtual;
		private
			freeRows: array [0..len-1] of boolean;
			freeMaxs, freeMins: array [0..2*len-1] of boolean;
			queenRows: array [0..len-1] of longint;
			function queens():boolean;
			function placeQueen(c: longint):boolean;
			function getRowColumn(r,c: longint):boolean;
			procedure setRowColumn(r,c: longint; v: boolean);
		end;
		
implementation

    constructor TQueens.init;
    begin
    	inherited init;
    end;
    
    destructor TQueens.deinit;
    begin
    	inherited deinit;
    end;
   
	function TQueens.queens():boolean;
	var i: longint;
	begin
		for i := 0 to len-1 do
		begin
		    freeRows[i] := true;
		    queenRows[i] := -1;
		end;
		
		for i := 0 to 2*len-1 do
		begin
		    freeMaxs[i] := true;
		    freeMins[i] := true;
		end;
		exit( placeQueen(0) );
	end;
	
	function TQueens.placeQueen(c: longint):boolean;
	var r: longint;
	begin
		for r := 0 to len-1 do
		begin
		  if getRowColumn(r, c) then
		  begin
		    queenRows[r] := c;
		    setRowColumn(r, c, false);

		    if c = 7 then exit(true);

		    if placeQueen(c + 1) then exit(true);
		    setRowColumn(r, c, true);
		  end;
		end;
		exit(false);
	end;
	
	function TQueens.getRowColumn(r,c: longint):boolean;
	begin
		exit( freeRows[r] and freeMaxs[c + r] and freeMins[c - r + 7] );
	end;
	
	procedure TQueens.setRowColumn(r,c: longint; v: boolean);
	begin
		freeRows[r        ] := v;
		freeMaxs[c + r    ] := v;
		freeMins[c - r + 7] := v;
	end;

    function TQueens.benchmark(): longint;
    var result: boolean; i: longint;
    begin
        result := true;
    	for i := 0 to 9 do
      		result := result and queens();
      	if result then exit(1) else exit(0);
    end;
    
    function TQueens.verifyResult(result: longint): boolean;
    begin
    	exit(result <> 0);
    end;
 
end.
