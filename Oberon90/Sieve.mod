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
 
MODULE Sieve;

IMPORT Benchmark, SOM, Out;

TYPE
  (* Publicly exported record type for the Sieve benchmark.
     It inherits from the base Benchmark type.  *)
  Sieve* = POINTER TO SieveDesc;
  SieveDesc* = RECORD (Benchmark.BenchmarkDesc) END;

  (* Helper record to wrap the integer result, making it a valid SOM.Object. *)
  IntegerObject = POINTER TO IntegerObjectDesc;
  IntegerObjectDesc = RECORD (SOM.ObjectDesc)
                      value: INTEGER;
                    END;

(* -------------------- Private Helper Procedures -------------------- *)

(* This is the core sieve algorithm. It is a local procedure *)
PROCEDURE DoSieve(flags: POINTER TO ARRAY OF BOOLEAN; size: INTEGER): INTEGER;
  VAR
    primeCount: INTEGER;
    i, k: INTEGER;
BEGIN
  primeCount := 0;
  FOR i := 2 TO size -1 DO
    IF flags[i] THEN
      INC(primeCount);
      k := i + i;
      WHILE k < size DO
        flags[k] := FALSE;
        k := k + i;
      END;
    END;
  END;
  RETURN primeCount;
END DoSieve;

(* -------------------- Public Procedures -------------------- *)

(* Public procedure to run the benchmark logic. *)
PROCEDURE DoBenchmark*(b: Benchmark.Benchmark): SOM.Object;
  VAR
    flags: POINTER TO ARRAY OF BOOLEAN;
    resultValue: INTEGER;
    i: INTEGER;
    resultObj: IntegerObject;
BEGIN
  NEW(flags, 5000);
  FOR i := 0 TO LEN(flags^) - 1 DO
    flags[i] := TRUE;
  END;

  resultValue := DoSieve(flags, 5000);

  (* Wrap the integer result in an object to return. *)
  NEW(resultObj);
  resultObj.value := resultValue;
  RETURN resultObj;
END DoBenchmark;

(* procedure to verify the benchmark's result. *)
PROCEDURE VerifyResult*(b: Benchmark.Benchmark; result: SOM.Object): BOOLEAN;
BEGIN
  WITH result: IntegerObject DO
    RETURN result.value = 669;
  ELSE
    Out.String("Sieve benchmark verification failed: result is not an IntegerObject."); Out.Ln;
    RETURN FALSE;
  END;
END VerifyResult;

(* Public factory procedure to create a new Sieve benchmark instance.
   This is the standard entry point for the harness. *)
PROCEDURE Create*(): Benchmark.Benchmark;
  VAR s: Sieve;
BEGIN
  NEW(s);
  (* We can assign our local procedures to the procedure variables
     of the parent Benchmark type to override the default behavior.
     This is how polymorphism is often achieved in Oberon. *)
  s.DoBenchmark := DoBenchmark;
  s.VerifyResult := VerifyResult;
  s.InnerBenchmarkLoop := Benchmark.InnerBenchmarkLoop;
  RETURN s;
END Create;

END Sieve.

