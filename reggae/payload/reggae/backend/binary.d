module reggae.backend.binary;


import reggae.build;
import reggae.range;
import reggae.options;
import reggae.file;
import reggae.dependencies;
import std.algorithm;
import std.range;
import std.file: thisExePath, exists;
import std.process: execute, executeShell;
import std.path: absolutePath;
import std.typecons: tuple;
import std.exception;
import std.stdio;
import std.parallelism: parallel;
import std.conv;
import std.array: replace, empty;
import std.string: strip;
import std.getopt;

@safe:

struct BinaryOptions {
    bool list;
    bool norerun;
    bool singleThreaded;
    private bool _earlyReturn;
    string[] args;

    this(string[] args) @trusted {
        auto optInfo = getopt(
            args,
            "list|l", "List available build targets", &list,
            "norerun|n", "Don't check for rerun", &norerun,
            "single|s", "Use only one thread", &singleThreaded,
            );
        if(optInfo.helpWanted) {
            defaultGetoptPrinter("Usage: build <targets>", optInfo.options);
            _earlyReturn = true;
        }
        if(list) {
            _earlyReturn = true;
        }

        this.args = args[1..$];
    }

    bool earlyReturn() const pure nothrow {
        return _earlyReturn;
    }
}

auto Binary(T)(Build build, in Options options, ref T output) {
    return BinaryT!(T)(build, options, output);
}

auto Binary(Build build, in Options options) @system {
    version(unittest) {
        import tests.utils;
        auto file = new FakeFile;
        return Binary(build, options, *file);
    }
    else
        return Binary(build, options, stdout);
}


struct BinaryT(T) {
    Build build;
    const(Options) options;
    T* output;

    this(Build build, in Options options, ref T output) @trusted {
        version(unittest) {
            static if(is(T == File)) {
                assert(&output != &stdout,
                       "stdio not allowed for Binary output in testing, "
                       "use tests.utils.FakeFile instead");
            }
        }

        this.build = build;
        this.options = options;
        this.output = &output;
    }

    void run(string[] args) @system { //@system due to parallel
        auto binaryOptions = BinaryOptions(args);

        handleOptions(binaryOptions);
        if(binaryOptions.earlyReturn) return;

        bool didAnything = binaryOptions.norerun ? false : checkReRun();

        auto topTargets = topLevelTargets(binaryOptions.args);
        if(topTargets.empty)
            throw new Exception(text("Unknown target(s) ", binaryOptions.args.map!(a => "'" ~ a ~ "'").join(" ")));

        foreach(topTarget; topTargets) {

            immutable didPhony = checkChildlessPhony(topTarget);
            didAnything = didPhony || didAnything;
            if(didPhony) continue;

            foreach(level; ByDepthLevel(topTarget)) {
                if(binaryOptions.singleThreaded)
                    foreach(target; level)
                        handleTarget(target, didAnything);
                else
                    foreach(target; level.parallel)
                        handleTarget(target, didAnything);
            }
        }
        if(!didAnything) output.writeln("[build] Nothing to do");
    }

    Target[] topLevelTargets(string[] args) @trusted pure {
        return args.empty ?
            build.defaultTargets.array :
            build.targets.filter!(a => args.canFind(a.expandOutputs(options.projectPath))).array;
    }

    string[] listTargets(BinaryOptions binaryOptions) pure {

        string targetOutputsString(in Target target) {
            return "- " ~ target.expandOutputs(options.projectPath).join(" ");
        }

        const defaultTargets = topLevelTargets(binaryOptions.args);
        auto optionalTargets = build.targets.filter!(a => !defaultTargets.canFind(a));
        return chain(defaultTargets.map!targetOutputsString,
                     optionalTargets.map!targetOutputsString.map!(a => a ~ " (optional)")).array;
    }


private:

    void handleTarget(Target target, ref bool didAnything) {
        const outs = target.expandOutputs(options.projectPath);
        immutable depFileName = outs[0] ~ ".dep";
        if(depFileName.exists) {
            didAnything = checkDeps(target, depFileName) || didAnything;
        }

        didAnything = checkTimestamps(target) || didAnything;
    }

    void handleOptions(BinaryOptions binaryOptions) {
        if(binaryOptions.list) {
            output.writeln("List of available top-level targets:");
            foreach(l; listTargets(binaryOptions)) output.writeln(l);
        }
    }

    bool checkReRun() {
        // don't bother if the build system was exported
        if(options.export_) return false;

        immutable myPath = thisExePath;
        if((options.reggaeFileDependencies ~ getReggaeFileDependencies).any!(a => a.newerThan(myPath))) {
            output.writeln("[build] " ~ options.rerunArgs.join(" "));
            immutable reggaeRes = execute(options.rerunArgs);
            enforce(reggaeRes.status == 0,
                    text("Could not run ", options.rerunArgs.join(" "), " to regenerate build:\n",
                         reggaeRes.output));
            output.writeln(reggaeRes.output);

            //currently not needed because generating the build also runs it.
            immutable buildRes = execute([myPath]);
            enforce(buildRes.status == 0, "Could not redo the build:\n", buildRes.output);
            output.writeln(buildRes.output);
            return true;
        }

        return false;
    }

    bool checkTimestamps(Target target) {
        auto allDeps = chain(target.dependencyTargets, target.implicitTargets);
        immutable isPhonyLike = target.getCommandType == CommandType.phony ||
            allDeps.empty;

        if(isPhonyLike) {
            executeCommand(target);
            return true;
        }

        foreach(dep; allDeps) {
            if(anyNewer(options.projectPath,
                        dep.expandOutputs(options.projectPath),
                        target)) {
                executeCommand(target);
                return true;
            }
        }

        return false;
    }

    //always run phony rules with no dependencies at top-level
    //ByDepthLevel won't include them
    bool checkChildlessPhony(Target target) {
        if(target.getCommandType == CommandType.phony &&
           target.dependencyTargets.empty && target.implicitTargets.empty) {
            executeCommand(target);
            return true;
        }
        return false;
    }

    //Checks dependencies listed in the .dep file created by the compiler
    bool checkDeps(Target target, in string depFileName) @trusted {
        auto file = File(depFileName);
        auto dependencies = file.byLine.map!(a => a.to!string).dependenciesFromFile;

        if(anyNewer(options.projectPath, dependencies, target)) {
            executeCommand(target);
            return true;
        }

        return false;
    }

    void executeCommand(Target target) @trusted {
        mkDir(target);
        auto targetOutput = target.execute(options);
        output.writeln("[build] ", targetOutput[0]);
        if(target.getCommandType == CommandType.phony && targetOutput.length > 1)
            output.writeln("\n", targetOutput[1]);
    }

    //@trusted because of mkdirRecurse
    private void mkDir(Target target) @trusted const {
        foreach(output; target.expandOutputs(options.projectPath)) {
            import std.file: exists, mkdirRecurse;
            import std.path: dirName;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }
}



bool anyNewer(in string projectPath, in string[] dependencies, in Target target) @safe {
    return cartesianProduct(dependencies, target.expandOutputs(projectPath)).
        any!(a => a[0].newerThan(a[1]));
}
