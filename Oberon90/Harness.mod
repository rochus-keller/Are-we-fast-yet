(* This code is derived from the SOM benchmarks, see AUTHORS.md file.
 *
 * Copyright (c) 2025 Rochus Keller <me@rochus-keller.ch> (for Oberon 90 migration)
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
 
MODULE Harness;

IMPORT Out, Input, Strings, Benchmark, Towers, Sieve, Queens, Storage, Permute, Mandelbrot
       List, Bounce, NBody, Richards;

TYPE
  Run = POINTER TO RunDesc;
  RunDesc = RECORD
    name: ARRAY 32 OF CHAR;
    benchmark: Benchmark.Benchmark;
    numIterations, innerIterations: INTEGER;
    total: LONGINT;
  END;

PROCEDURE SelectBenchmark(name: ARRAY OF CHAR): Benchmark.Benchmark;
BEGIN
  IF name = "Towers" THEN RETURN Towers.Create()
  ELSIF name = "Sieve" THEN RETURN Sieve.Create()
  ELSIF name = "Queens" THEN RETURN Queens.Create()
  ELSIF name = "Storage" THEN RETURN Storage.Create()
  ELSIF name = "Permute" THEN RETURN Permute.Create()
  ELSIF name = "Mandelbrot" THEN RETURN Mandelbrot.Create()
  ELSIF name = "List" THEN RETURN List.Create()
  ELSIF name = "Bounce" THEN RETURN Bounce.Create()
  ELSIF name = "NBody" THEN RETURN NBody.Create()
  ELSIF name = "Richards" THEN RETURN Richards.Create()
  (*
  ELSIF name = "Json" THEN RETURN Json.Create()
  ELSIF name = "CD" THEN RETURN CD.Create()
  ELSIF name = "DeltaBlue" THEN RETURN DeltaBlue.Create()
  ELSIF name = "Havlak" THEN RETURN Havlak.Create()
  *)
  ELSE Out.String("Benchmark not found: "); Out.String(name); Out.Ln; HALT(100);
  END;
  RETURN NIL;
END SelectBenchmark;

PROCEDURE Measure(run: Run);
  VAR startTime, endTime, runTime: LONGINT;
BEGIN
  startTime := Input.Time();
  IF ~run.benchmark.InnerBenchmarkLoop(run.benchmark,run.innerIterations) THEN
    Out.String("Benchmark failed with incorrect result."); Out.Ln;
    HALT(101);
  END;
  endTime := Input.Time();
  runTime := endTime - startTime;
  
  (* we don't use intermediate results
  Out.String(run.name); Out.String(": iterations=1 runtime: ");
  Out.Int(runTime * 1000, 0); Out.String("us"); Out.Ln;
  *)
  run.total := run.total + runTime;
END Measure;

PROCEDURE DoRuns(run: Run);
  VAR i: INTEGER;
BEGIN
  FOR i := 1 TO run.numIterations DO
    Measure(run);
  END;
END DoRuns;

PROCEDURE ReportBenchmark(run: Run);
  VAR avg: LONGINT;
BEGIN
  Out.String(run.name); Out.String(": iterations="); Out.Int(run.numIterations, 0);
  avg := run.total DIV run.numIterations;
  Out.String(" average: "); Out.Int(avg, 0); Out.String("us total: ");
  Out.Int(run.total, 0); Out.String("us"); Out.Ln; Out.Ln;
END ReportBenchmark;

PROCEDURE RunBenchmark(run: Run);
BEGIN
  Out.String("Starting "); Out.String(run.name); Out.String(" benchmark ..."); Out.Ln;
  DoRuns(run);
  ReportBenchmark(run);
END RunBenchmark;

PROCEDURE PrintTotal(run: Run);
BEGIN
  (* we don't need this information
  Out.String("Total Runtime: "); Out.Int(run.total, 0); Out.String("us"); Out.Ln;
  *)
END PrintTotal;


PROCEDURE DoRun(what : ARRAY OF CHAR; numIterations, innerIterations: INTEGER);
  VAR run: Run;
BEGIN
  NEW(run);
  COPY(what, run.name); 
  run.numIterations := numIterations;
  run.innerIterations := innerIterations;
  run.total := 0;
  run.benchmark := SelectBenchmark(run.name);
  RunBenchmark(run);
  PrintTotal(run);
END DoRun;

BEGIN
  DoRun("Sieve", 1, 1);
  DoRun("Towers", 1, 1);
  DoRun("Queens", 1, 1);
  DoRun("Storage", 1, 1);
  DoRun("Permute", 1, 1);
  DoRun("List", 1, 1);
  DoRun("Bounce", 1, 1);
  DoRun("Mandelbrot", 1, 1);
  DoRun("NBody", 1, 1);
  DoRun("Richards", 1, 1);
END Harness.

