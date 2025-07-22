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
 
MODULE Random;

(*
  A simple Linear Congruential Generator (LCG) used by benchmarks like Storage.
*)

IMPORT SOM;

CONST
  InitialSeed = 74755;

TYPE
  INT32  = SOM.INT32;
  Random* = POINTER TO RandomDesc;
  RandomDesc* = RECORD
    seed: INT32;
  END;

PROCEDURE Create*(): Random;
  VAR r: Random;
BEGIN
  NEW(r);
  r.seed := InitialSeed;
  RETURN r;
END Create;

PROCEDURE Next*(r: Random): INT32;
BEGIN
  (* The bitwise AND with 65535 is equivalent to MOD 65536. *)
  r.seed := ((r.seed * 1309) + 13849) MOD 65536;
  RETURN r.seed;
END Next;

END Random.

