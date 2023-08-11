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
 
unit Run;
interface
uses 
	Benchmark;
	
type
	PBenchmark = ^TBenchmark;
    TRun = object
    public
		name: string;
		benchmarkSuite: PBenchmark;
		numIterations, innerIterations, total: longint;
        constructor init(name_: string);
        destructor deinit;
        procedure runBenchmark();
        procedure printTotal();
        procedure setNumIterations(numIterations_: longint);
        procedure setInnerIterations(innerIterations_: longint);
    private
    	procedure measure(bench: PBenchmark);
    	procedure doRuns(bench: PBenchmark);
    	procedure reportBenchmark();
    	procedure printResult(runTime: longint);
    end;

implementation
uses
	unix, math, Mandelbrot, NBody, Permute, Queens, Sieve, Storage, Towers;
	
	function getSuiteFromName(name: string): PBenchmark;
	var bench: PBenchmark;
	begin
		bench := nil;
		if name = 'Mandelbrot' then bench := new (PMandelbrot,init);
		if name = 'NBody' then bench := new (PNBody,init);
		if name = 'Permute' then bench := new (PPermute,init);
		if name = 'Queens' then bench := new (PQueens,init);
		if name = 'Sieve' then bench := new (PSieve,init);
		if name = 'Storage' then bench := new (PStorage,init);
		if name = 'Towers' then bench := new (PTowers,init);
		exit(bench);
	end;

    constructor TRun.init(name_: string);
    begin
    	name := name_;
    	numIterations := 1;
    	innerIterations := 1;
    	total := 0;
    	benchmarkSuite := getSuiteFromName(name);
    end;

    destructor TRun.deinit;
    begin
    	if benchmarkSuite <> nil then dispose(benchmarkSuite,deinit);
    end;

    procedure TRun.runBenchmark();
    begin
    	if benchmarkSuite = nil then
    	begin
    		WriteLn('ERROR unknown benchmark '+ name );
    		halt;
    	end;
    	WriteLn('Starting ' + name + ' benchmark ...');
    	doRuns(benchmarkSuite);
    	dispose(benchmarkSuite,deinit);
    	benchmarkSuite := nil;
    	reportBenchmark();
		WriteLn;
    end;
    
    procedure TRun.printTotal();
    begin
    	// NOP
    end;
    
    procedure TRun.setNumIterations(numIterations_: longint);
    begin
      	numIterations := numIterations_;
    end;
    
    procedure TRun.setInnerIterations(innerIterations_: longint);
    begin
    	innerIterations := innerIterations_;
    end;
    
    procedure TRun.measure(bench: PBenchmark);
    var
    	runTime, seconds, microseconds: longint;
    	start, end_: timeval;
    begin
    	fpgettimeofday(@start, nil);
    	if not bench^.innerBenchmarkLoop(innerIterations) then 
    	begin
    		WriteLn('Benchmark failed with incorrect result');
    		exit;
    	end;
    	fpgettimeofday(@end_, nil);
    	seconds := end_.tv_sec - start.tv_sec;
    	microseconds := end_.tv_usec - start.tv_usec;
    	runTime := seconds*1000000 + microseconds; // us
		printResult(runTime);
		total := total + runTime;
    end;
    
	procedure TRun.doRuns(bench: PBenchmark);
	var i: longint;
	begin
		for i := 1 to numIterations do measure(bench);
	end;
	
	procedure TRun.reportBenchmark();
	begin
    	Write(name + ': iterations=');
    	Write(numIterations);
        Write(' average: ');
        Write(total div numIterations);
        Write('us total: ');
        Write(total);
        WriteLn('us');
	end;
	
	procedure TRun.printResult(runTime: longint);
	begin
		// NOP
	end;

end.
