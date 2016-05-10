/**

 This module implements the binary that is used to generate the build
 in the case of the make, ninja and tup backends, i.e. it translates
 D code into the respective output.

 For the binary target this module implements the binary that actually
 performs the build

 */

module reggae.buildgen;

import reggae.build;
import reggae.options;
import reggae.types;
import reggae.backend;
import reggae.reflect;

import std.stdio;
import std.file: timeLastModified;

/**
 Creates a build generator out of a module and a list of top-level targets.
 This will define a function with the signature $(D Build buildFunc()) in
 the calling module and a $(D main) entry point function for a command-line
 executable.
 */
mixin template buildGen(string buildModule, targets...) {
    mixin buildImpl!targets;
    mixin BuildGenMain!buildModule;
}

mixin template BuildGenMain(string buildModule = "reggaefile") {
    import std.stdio;

    // args is empty except for the binary backend,
    // in which case it's used for runtime options
    int main(string[] args) {
        try {
            import reggae.config: options;
            doBuildFor!(buildModule)(options, args); //the user's build description
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void doBuildFor(alias module_ = "reggaefile")(in Options options, string[] args = []) {
    auto build = getBuildObject!module_(options);
    if(!options.noCompilationDB) writeCompilationDB(build, options);
    doBuild(build, options, args);
}

// calls the build function or loads it from the cache and returns
// the Build object
Build getBuildObject(alias module_)(in Options options) {
    import std.path;
    import std.file;

    immutable cacheFileName = buildPath(".reggae", "cache");
    if(!options.cacheBuildInfo ||
       !cacheFileName.exists ||
        thisExePath.timeLastModified > cacheFileName.timeLastModified) {
        const buildFunc = getBuild!(module_); //get the function to call by CT reflection
        auto build = buildFunc(); //actually call the function to get the build description

        if(options.cacheBuildInfo) {
            auto file = File(cacheFileName, "w");
            file.rawWrite(build.toBytes(options));
        }

        return build;
    } else {
        auto file = File(cacheFileName);
        auto buffer = new ubyte[cast(uint)file.size];
        return Build.fromBytes(file.rawRead(buffer));
    }
}

void doBuild(Build build, in Options options, string[] args = []) {
    options.export_ ? exportBuild(build, options) : doOneBuild(build, options, args);
}


private void doOneBuild(Build build, in Options options, string[] args = []) {
    final switch(options.backend) with(Backend) {

        version(minimal) {
            import std.conv;

            case make:
            case ninja:
            case tup:
                throw new Exception(text("Support for ", options.backend, " not compiled in"));
        } else {

            case make:
                writeBuild!Makefile(build, options);
                break;

            case ninja:
                writeBuild!Ninja(build, options);
                break;

            case tup:
                writeBuild!Tup(build, options);
                break;
        }

        case binary:
            Binary(build, options).run(args);
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void exportBuild(Build build, in Options options) {
    import std.exception;
    import std.meta;

    enforce(options.backend == Backend.none, "Cannot specify a backend and export at the same time");

    version(minimal)
        throw new Exception("export not supported in minimal version");
    else
        foreach(backend; AliasSeq!(Makefile, Ninja, Tup))
            writeBuild!backend(build, options);
}

private void writeBuild(T)(Build build, in Options options) {
    version(minimal)
        throw new Exception(T.stringof ~ " backend support not compiled in");
    else
        T(build, options).writeBuild;
}


private void writeCompilationDB(Build build, in Options options) {
    import std.file;
    import std.conv;
    import std.algorithm;
    import std.string;
    import std.path;

    auto file = File(buildPath(options.workingDir, "compile_commands.json"), "w");
    file.writeln("[");

    immutable cwd = getcwd;
    string entry(Target target) {
        return
            "    {\n" ~
            text(`        "directory": "`, cwd, `"`) ~ ",\n" ~
            text(`        "command": "`, target.shellCommand(options), `"`) ~ ",\n" ~
            text(`        "file": "`, target.expandOutputs(options.projectPath).join(" "), `"`) ~ "\n" ~
            "    }";
    }

    file.write(build.range.map!(a => entry(a)).join(",\n"));
    file.writeln;
    file.writeln("]");
}
