(* Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch>
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
unit RefCounted;
interface
	type
		TRefCountedPtr = ^TRefCounted;
		TRefCounted = object
					public
						constructor init();
						destructor deinit(); virtual;
					private
						refCount: longint;
					end;
	procedure addRef(ptr: TRefCountedPtr);
	procedure release(ptr: TRefCountedPtr);
	
implementation

	constructor TRefCounted.init();
	begin
		refCount := 0;
	end;
	
	destructor TRefCounted.deinit();
	begin
	end;

	procedure addRef(ptr: TRefCountedPtr);
	begin
		if ptr = nil then exit;
		ptr^.refCount += 1;
	end;
	
	procedure release(ptr: TRefCountedPtr);
	begin
		if ptr = nil then exit;
		ptr^.refCount -= 1;
		if ptr^.refCount <= 0 then dispose(ptr,deinit);
	end;

end.
