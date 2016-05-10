module reggae.range;

import reggae.build;
import reggae.options;

import std.range;
import std.algorithm;
import std.conv;
import std.exception;

@safe:

enum isTargetLike(T) = is(typeof(() {
    auto target = T.init;
    auto deps = target.dependencyTargets;
    static assert(is(Unqual!(typeof(deps[0])) == Unqual!T));
    auto imps = target.implicitTargets;
    static assert(is(Unqual!(typeof(imps[0])) == Unqual!T));
    if(target.isLeaf) {}
    string cmd = target.shellCommand(Options());
}));


static assert(isTargetLike!Target);

struct DepthFirst(T) if(isTargetLike!T) {
    T[] targets;

    this(T target) pure {
        this.targets = depthFirstTargets(target);
    }

    T[] depthFirstTargets(T target) pure {
        //if leaf, return
        if(target.isLeaf) return target.shellCommand(Options()) is null ? [] : [target];

        //if not, add ourselves to the end to get depth-first
        return reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.dependencyTargets) ~
            reduce!((a, b) => a ~ depthFirstTargets(b))(typeof(return).init, target.implicitTargets) ~
            target;
    }

    T front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }

    static assert(isInputRange!DepthFirst);
}

auto depthFirst(T)(T target) pure {
    return DepthFirst!T(target);
}

struct ByDepthLevel {
    Target[][] targets;

    this(Target target) pure {
        this.targets = sortTargets(target);
    }

    auto front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }

    private Target[][] sortTargets(Target target) pure {
        if(target.isLeaf) return [];

        Target[][] targets = [[target]];
        rec(0, [target], targets);
        return targets.
            retro.
            map!(a =>
                 a.sort!((x, y) => x.rawOutputs < y.rawOutputs).
                 uniq!((x, y) => equal(x.rawOutputs, y.rawOutputs)).array).
            array;
    }

    private void rec(int level, Target[] targets, ref Target[][] soFar) @trusted pure nothrow {
        Target[] notLeaves = targets.
            map!(a => chain(a.dependencyTargets, a.implicitTargets)). //get all dependencies
            join. //flatten into a regular range
            filter!(a => !a.isLeaf). //don't care about leaves
            array;
        if(notLeaves.empty) return;

        soFar ~= notLeaves;
        rec(level + 1, notLeaves, soFar);
    }

    static assert(isInputRange!ByDepthLevel);
}

struct Leaves {
    this(in Target target) pure nothrow {
        recurse(target);
    }

    const(Target) front() pure nothrow {
        return targets.front;
    }

    void popFront() pure nothrow {
        targets.popFront;
    }

    bool empty() pure nothrow {
        return targets.empty;
    }


private:

    const(Target)[] targets;

    void recurse(in Target target) pure nothrow {
        if(target.isLeaf) {
            targets ~= target;
            return;
        }

        foreach(dep; target.dependencyTargets ~ target.implicitTargets) {
            if(dep.isLeaf) {
                targets ~= dep;
            } else {
                recurse(dep);
            }
        }
    }

    static assert(isInputRange!Leaves);
}


//TODO: a non-allocating version with no arrays
auto noSortUniq(R)(R range) if(isInputRange!R) {
    ElementType!R[] ret;
    foreach(elt; range) {
        if(!ret.canFind(elt)) ret ~= elt;
    }
    return ret;
}

//removes duplicate targets from the build, presents a depth-first interface
//per top-level target
struct UniqueDepthFirst {
    Build build;
    private Target[] _targets;

    this(Build build) pure @trusted {
        _targets = build.targets.
            map!depthFirst.
            join.
            noSortUniq.
            array;
    }

    Target front() pure nothrow {
        return _targets.front;
    }

    void popFront() pure nothrow {
        _targets.popFront;
    }

    bool empty() pure nothrow {
        return _targets.empty;
    }

    static assert(isInputRange!UniqueDepthFirst);
}
