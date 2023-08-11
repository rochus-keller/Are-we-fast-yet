(* Copyright (c) 2023 Rochus Keller <me@rochus-keller.ch>
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

program Main;
	uses Run;

	procedure dorun(what: string; numIterations, innerIterations: longint);
	var r: TRun;
	begin
		r.init(what);
		r.setNumIterations(numIterations);
		r.setInnerIterations(innerIterations);
		    r.runBenchmark();
		    r.printTotal();
	end;
	
	procedure runAll();
	begin
		dorun('DeltaBlue', 12000, 1 );
		dorun('Richards', 100, 1);
		dorun('Json', 100, 1);
		dorun('Havlak', 10, 1 );
		dorun('CD', 250, 2);
		dorun('Bounce', 1500, 1);
		dorun('List', 1500, 1);
		dorun('Mandelbrot', 500, 1);
		dorun('NBody', 250000, 1);
		dorun('Permute', 1000, 1);
		dorun('Queens', 1000, 1);
		dorun('Sieve', 3000, 1);
		dorun('Storage', 1000, 1);
		dorun('Towers', 600, 1);
	end;
	
	procedure runOnce();
	begin
		dorun('DeltaBlue', 1, 1 );
		dorun('Richards', 1, 1);
		dorun('Json', 1, 1);
		dorun('Havlak', 1, 1 );
		dorun('CD', 1, 2);
		dorun('Bounce', 1, 1);
		dorun('List', 1, 1);
		dorun('Mandelbrot', 1, 1);
		dorun('NBody', 1, 1);
		dorun('Permute', 1, 1);
		dorun('Queens', 1, 1);
		dorun('Sieve', 1, 1);
		dorun('Storage', 1, 1);
		dorun('Towers', 1, 1);
	end;
	
begin
	//runOnce;
		dorun('Bounce', 1500, 1);
		dorun('List', 1500, 1);
		dorun('Mandelbrot', 500, 1);
		dorun('NBody', 250000, 1);
		dorun('Permute', 1000, 1);
		dorun('Queens', 1000, 1);
		dorun('Sieve', 3000, 1);
		dorun('Storage', 1000, 1);
		dorun('Towers', 600, 1);
end.
