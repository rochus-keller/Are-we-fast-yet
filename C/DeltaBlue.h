#ifndef _DELTABLUE_H
#define _DELTABLUE_H

/* Copyright (c) 2024 Rochus Keller <me@rochus-keller.ch> (for C99 migration)
 *
 * This benchmark is derived from Mario Wolczko's Java and Smalltalk version of
 * DeltaBlue.
 *
 * It is modified to use the SOM class library and Java 8 features.
 * License details:
 *   http://web.archive.org/web/20050825101121/http://www.sunlabs.com/people/mario/java_benchmarking/index.html
 */

#include "Benchmark.h"

extern Benchmark* DeltaBlue_create();

#endif // _DELTABLUE_H
