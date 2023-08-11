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
 
unit Towers;
interface
uses Benchmark;

const PilesCount = 3;

type
	TowersDiskPtr = ^TowersDisk;
	PTowers = ^TTowers;
	TTowers = object(TBenchmark)
				constructor init;
				destructor deinit; virtual;
				function benchmark(): longint; virtual;
				function verifyResult(result: longint): boolean; virtual;
			private
				piles: array [0..PilesCount-1] of TowersDiskPtr;
				movesDone: longint;
				procedure pushDisk(disk: TowersDiskPtr; pile: longint);
				function popDiskFrom(pile: longint): TowersDiskPtr;
				procedure moveTopDisk(fromPile, toPile: longint);
				procedure buildTowerAt(pile, disks: longint);
				procedure moveDisks(disks, fromPile, toPile: longint);
			end;
	TowersDisk = object
					constructor init(s: longint);
					destructor deinit;
				private
					size: longint;
					next: TowersDiskPtr;
					function getNext():TowersDiskPtr;
					procedure setNext(ptr:TowersDiskPtr);
					function getSize():longint;
				end;
				
implementation

	constructor TowersDisk.init(s: longint);
	begin;
		size := s;
	end;
	
	destructor TowersDisk.deinit;
	begin
		if next <> nil then dispose(next,deinit);
	end;
	
	function TowersDisk.getNext():TowersDiskPtr;
	begin
		exit(next);
	end;
	
	function TowersDisk.getSize():longint;
	begin
		exit(size);
	end;

	procedure TowersDisk.setNext(ptr:TowersDiskPtr);
	begin
		next := ptr;
	end;

    constructor TTowers.init;
    begin
    	inherited init;
    end;
    
    destructor TTowers.deinit;
    begin
    	inherited deinit;
    end;
    
	procedure TTowers.pushDisk(disk: TowersDiskPtr; pile: longint);
	var top: TowersDiskPtr;
	begin
		top := piles[pile];
		if (top <> nil) and (disk^.getSize() >= top^.getSize()) then
		begin
		    WriteLn('Cannot put a big disk on a smaller one');
		    halt;
		end;

		disk^.setNext(top);
		piles[pile] := disk;
	end;
	
	function TTowers.popDiskFrom(pile: longint): TowersDiskPtr;
	var top: TowersDiskPtr;
	begin
		top := piles[pile];
		if top =  nil then
		begin
		    WriteLn('Attempting to remove a disk from an empty pile');
		    halt;
		end;

		piles[pile] := top^.getNext();
		top^.setNext(nil);
		exit(top);
	end;
	
	procedure TTowers.moveTopDisk(fromPile, toPile: longint);
	begin
		pushDisk(popDiskFrom(fromPile), toPile);
		movesDone += 1;
	end;
	
	procedure TTowers.buildTowerAt(pile, disks: longint);
	var i: longint;
		t: TowersDiskPtr;
	begin
		for i := disks downto 0 do
		begin
			new(t);
			t^.init(i);
		    pushDisk(t, pile);
		end;
	end;
	
	procedure TTowers.moveDisks(disks, fromPile, toPile: longint);
	var otherPile: longint;
	begin
		if disks = 1 then
			begin
		    	moveTopDisk(fromPile, toPile);
		    end
		else 
			begin
				otherPile := (3 - fromPile) - toPile;
				moveDisks(disks - 1, fromPile, otherPile);
				moveTopDisk(fromPile, toPile);
				moveDisks(disks - 1, otherPile, toPile);
			end;
	end;

    function TTowers.benchmark(): longint;
    var i: longint;
    begin
		for i := 0 to PilesCount -1 do
		    piles[i] := nil;
		buildTowerAt(0, 13);
		movesDone := 0;
		moveDisks(13, 0, 1);
		for i := 0 to PilesCount -1 do
		    if piles[i] <> nil then
		        dispose(piles[i],deinit);
		exit(movesDone);
    end;
    
    function TTowers.verifyResult(result: longint): boolean;
    begin
    	exit(8191 = result);
    end;
    
end.
