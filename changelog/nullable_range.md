The range API functions on `Nullable` have been deprecated.

Treating `Nullable` as a range has been causing problems for generic code
similar to when `Nullable` used `alias this` with `get`, so it was clearly
a mistake to add that functionality. As with implicitly converting `Nullable`
to the type it contains, implictly converting it to a range of the type that
it contains is just too bug-prone.

As with containers, `Nullable` supports slicing to get a range, so anyone who
wishes to use a `Nullable` as a range can simply slice it.

Examples:
--
auto n = nullable(42);

// deprecated
auto value = n.front;

// This still works
auto range = n[];
assert(range.front == 42);
--
