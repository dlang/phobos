Added `staticArray` to construct a static array from array / input range. Includes a length-inferring compile-time variant.

The type of elements can be specified implicitly so that $(D [1, 2].staticArray) results in `int[2]`,
or explicitly, e.g. $(D [1, 2].staticArray!float) returns `float[2]`.
When `a` is a range whose length is not known at compile time, the number of elements must be given as template argument
(e.g. `myrange.staticArray!2`).
Size and type can be combined, if the source range elements are implicitly
convertible to the requested element type (eg: `2.iota.staticArray!(long[2])`).
When the range `a` is known at compile time, it can also be specified as a
template argument to avoid having to specify the number of elements
(e.g.: `staticArray!(2.iota)` or `staticArray!(double, 2.iota)`).

---
import std.range : iota;

auto input = 3.iota;
auto a = input.staticArray!2;
static assert(is(typeof(a) == int[2]));
assert(a == [0, 1]);
auto b = input.staticArray!(long[4]);
static assert(is(typeof(b) == long[4]));
assert(b == [0, 1, 2, 0]);
---
