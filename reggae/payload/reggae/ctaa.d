module reggae.ctaa;

import std.traits;

/**
An implementation of an associative array useable at compile-time.
Shameless copy of association lists from Lisp.
 */


@safe:


struct AssocList(K, V) {
    import std.algorithm: find, canFind;
    import std.array: empty, front;

    AssocEntry!(K, V)[] entries;

    const(V) opIndex(in K key) pure const nothrow {
        auto res = entries.find!(a => a.key == key);
        assert(!res.empty, "AssocList does not contain key " ~ key);
        return res.front.value;
    }

    void opIndexAssign(V value, K key) {
        entries ~= AssocEntry!(K, V)(key, value);
    }

    T get(T)(in K key, T defaultValue) pure const {
        import std.conv: to;
        auto res = entries.find!(a => a.key == key);
        return res.empty ? defaultValue : res.front.value.to!T;
    }

    const(K)[] keys() pure const nothrow {
        import std.algorithm: map;
        import std.array: array;
        return entries.map!(a => a.key).array;
    }

    bool opBinaryRight(string op)(in K key) pure const if(op == "in") {
        return entries.canFind!(a => a.key == key);
    }

    V[K] toAA() {
        V[K] ret;
        foreach(entry; entries) {
            ret[entry.key] = entry.value;
        }
        return ret;
    }

    string toString() const pure @safe {
        import std.conv;
        import std.algorithm;
        import std.range;
        return `{` ~ entries.map!(a => text(a.key, ": ", a.value)).join(", ") ~ `}`;
    }
}

AssocList!(K, V) fromAA(K, V)(V[K] aa) {
    AssocEntry!(K, V)[] entries;
    foreach(k, v; aa) entries ~= assocEntry(k, v);
    return AssocList!(K, V)(entries);
}

struct AssocEntry(K, V) {
    K key;
    V value;
}


AssocEntry!(K, V) assocEntry(K, V)(K key, V value) {
    return AssocEntry!(K, V)(key, value);
}

AssocList!(K, V) assocList(K, V)(AssocEntry!(K, V)[] entries = []) {
    return AssocList!(K, V)(entries);
}

auto assocListT(T...)(T args) if(T.length % 2 == 0 && T.length > 0) {
    alias K = T[0];
    alias V = T[1];
    AssocEntry!(K, V)[] entries;
    foreach(i, elt; args) {
        static if(i % 2 == 0) entries ~= assocEntry(args[i], args[i+1]);
    }
    return AssocList!(K, V)(entries);
}
