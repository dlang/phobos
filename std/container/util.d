module std.container.util;

import std.algorithm;

/**
Returns an initialized object. This function is mainly for eliminating
construction differences between structs and classes. It allows code to not
worry about whether the type it's constructing is a struct or a class.

Examples:
--------------------
auto arr = make!(Array!int)([4, 2, 3, 1]);
assert(equal(arr[], [4, 2, 3, 1]));

auto rbt = make!(RedBlackTree!(int, "a > b"))([4, 2, 3, 1]);
assert(equal(rbt[], [4, 3, 2, 1]));

alias makeList = make!(DList!int);
auto list = makeList([1, 7, 42]);
assert(equal(list[], [1, 7, 42]));
--------------------
 */
template make(T)
if (is(T == struct) || is(T == class))
{
    T make(Args...)(Args arguments)
    if (is(T == struct) && __traits(compiles, T(arguments)))
    {
        return T(arguments);
    }

    T make(Args...)(Args arguments)
    if (is(T == class) && __traits(compiles, new T(arguments)))
    {
        return new T(arguments);
    }
}

//Verify Examples.
unittest
{
    import std.container;
    
    auto arr = make!(Array!int)([4, 2, 3, 1]);
    assert(equal(arr[], [4, 2, 3, 1]));

    auto rbt = make!(RedBlackTree!(int, "a > b"))([4, 2, 3, 1]);
    assert(equal(rbt[], [4, 3, 2, 1]));

    alias makeList = make!(DList!int);
    auto list = makeList([1, 7, 42]);
    assert(equal(list[], [1, 7, 42]));
    
    auto s = make!(SList!int)(1, 2, 3);
    assert(equal(s[], [1, 2, 3]));
}

unittest
{
    import std.container;
    
    auto arr1 = make!(Array!dchar)();
    assert(arr1.empty);
    auto arr2 = make!(Array!dchar)("hello"d);
    assert(equal(arr2[], "hello"d));

    auto rtb1 = make!(RedBlackTree!dchar)();
    assert(rtb1.empty);
    auto rtb2 = make!(RedBlackTree!dchar)('h', 'e', 'l', 'l', 'o');
    assert(equal(rtb2[], "ehlo"d));
}

// Issue 8895
unittest
{
    import std.container;
    
    auto a = make!(DList!int)(1,2,3,4);
    auto b = make!(DList!int)(1,2,3,4);
    auto c = make!(DList!int)(1,2,3,5);
    auto d = make!(DList!int)(1,2,3,4,5);
    assert(a == b); // this better terminate!
    assert(!(a == c));
    assert(!(a == d));
}