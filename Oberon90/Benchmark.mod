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

MODULE Benchmark;

IMPORT SOM, Out;

TYPE
  INT32* = SOM.INT32;
  Benchmark* = POINTER TO BenchmarkDesc;
  BenchmarkDesc* = RECORD (SOM.ObjectDesc) 
                      InnerBenchmarkLoop*: PROCEDURE(b: Benchmark; innerIterations: INTEGER): BOOLEAN;
                      DoBenchmark*: PROCEDURE(b: Benchmark): SOM.Object;
                      VerifyResult*: PROCEDURE(b: Benchmark; result: SOM.Object): BOOLEAN;
                  END;

PROCEDURE InnerBenchmarkLoop*(b: Benchmark; innerIterations: INTEGER): BOOLEAN;
  VAR i: INTEGER; result: SOM.Object; success: BOOLEAN;
BEGIN
  i := 0;
  success := TRUE;
  WHILE (i < innerIterations) & success DO
    result := b.DoBenchmark(b);
    success := b.VerifyResult(b, result);
    INC(i);
  END;
  RETURN success;
END InnerBenchmarkLoop;

PROCEDURE DoBenchmark(b: Benchmark): SOM.Object;
BEGIN
  Out.String("Subclass responsibility"); Out.Ln;
  HALT(100);
  RETURN NIL
END DoBenchmark;

PROCEDURE VerifyResult(b: Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  Out.String("Subclass responsibility"); Out.Ln;
  HALT(100);
  RETURN FALSE
END VerifyResult;

PROCEDURE Create(): Benchmark;
  VAR b: Benchmark;
BEGIN
  NEW(b);
  b.DoBenchmark := DoBenchmark;
  b.VerifyResult := VerifyResult;
  b.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN b;
END Create;

END Benchmark.

