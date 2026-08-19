This version of the "Are We Fast Yet?" benchmark suite is based on the
[Hybrid](../Hybrid) version, but it uses an interface with four methods to represent a benchmark
(instead of the Oberon-style record with four procedure type fields).

Each benchmark creates a heap allocated record whose type-bound procedures structurally 
satisfy this interface.

All modules are still on language level 2 or 3, i.e. there is no object-orientation
or virtual dispatch involved, but all calls resolve at compile time.

