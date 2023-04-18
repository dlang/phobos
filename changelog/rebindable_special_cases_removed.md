`std.typecons.Rebindable` no longer has special handling for arrays, classes and interfaces.

Previously, `Rebindable!(const T[])` used to simply alias to `const(T)[]`, creating a mutable version of
the parameter type. This special case has been removed, and `Rebindable!(const T[])` is now a struct, just
as every other instance of `Rebindable`.

The same goes for classes: `Rebindable!C` used to just alias to `C` if `C` was not const or immutable.
This special case has also been removed.

As a consequence, when you declare `Rebindable!T foo`, you can now always write `foo.get` to get a value of
type `T`. This is expected to reduce the amount of required specialcasing in template code that uses
`Rebindable`.
