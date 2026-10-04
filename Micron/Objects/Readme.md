This version of the "Are We Fast Yet?" benchmark suite is based on the
[C++ version](https://github.com/rochus-keller/Are-we-fast-yet/tree/main/Cpp)),
i.e. using OBJECT types, inheritance, dynamically dispatched type-bound procedures, IS, type guards and type CASE.

Each benchmark creates a heap allocated record whose type-bound procedures overload
the inherited methods. 

All modules (besides Random) are on language level 4.

