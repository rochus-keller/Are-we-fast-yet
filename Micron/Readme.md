Here you find implementations of the benchmark suite written in the 
[Micron programming language](https://github.com/micron-language/specification/).

Micron supports different "language levels" dedicated to different use cases from
lowest-level kernel implementation (with no stack or heap) up to high-level
managed applications supported by a garbage collector. Level 1 roughly corresponds
to what the C programming language can do. Level 2 in addition offers things like
structuraly typed interfaces found in the Go programming language. Only on
level 3 there is built-in dynamic memory management. 

But even within language levels, there is support for different programming paradigms.
Level 1 not only supports procedural programming, but also procedures (statically)
bound to record types, which helps to get rid of a lot of boiler-plate text, as well
as type-bound procedure types (i.e. "delegates"). The latter support a "hybrid" 
programming approach between procedural and object-oriented, similar to the Go
programming language, but much leaner and less confusing.

So far, there are two implementations of the benchmark suite, one using plain
procedural style with code directly migrated from the C version of the benchmark suite,
and one using the hybrid style which resembles the C++ implementation to a certain
degree, but the use of delegates to emulate the closures and iterators of the 
original Smalltalk implementation of the benchmark suite is much leaner than the
implementation based on inheritance and virtual methods found in C++. 

This benchmark suite implementation is therefore a good case study for examining 
the different programming styles that Micron supports, even for low-level programming.
