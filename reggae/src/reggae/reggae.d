/**
 The main entry point for the reggae tool. Its tasks are:
 $(UL
   $(LI Verify that a $(D reggafile.d) exists in the selected directory)
   $(LI Generate a $(D reggaefile.d) for dub projects)
   $(LI Write out the reggae library files and $(D config.d))
   $(LI Compile the build description with the reggae library files to produce $(D buildgen))
   $(LI Produce $(D dcompile), a binary to call the D compiler to obtain dependencies during compilation)
   $(LI Call the produced $(D buildgen) binary)
 )
 */


module reggae.reggae;

import std.stdio;
import std.process: execute, environment;
import std.array: array, join, empty, split;
import std.path: absolutePath, buildPath, relativePath;
import std.typetuple;
import std.file;
import std.conv: text;
import std.exception: enforce;
import std.conv: to;
import std.algorithm;

import reggae.options;
import reggae.ctaa;
import reggae.types;
import reggae.file;


version(minimal) {
    //empty stubs for minimal version of reggae
    void maybeCreateReggaefile(T...)(T) {}
    void writeDubConfig(T...)(T) {}
} else {
    import reggae.dub.interop;
}

mixin template reggaeGen(targets...) {
    mixin buildImpl!targets;
    mixin ReggaeMain;
}

mixin template ReggaeMain() {
    import reggae.options: getOptions;
    import std.stdio: stdout, stderr;

    int main(string[] args) {
        try {
            run(stdout, args);
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void run(T)(T output, string[] args) {
    auto options = getOptions(args);
    run(output, options);
}

void run(T)(T output, Options options) {
    if(options.earlyExit) return;
    enforce(options.projectPath != "", "A project path must be specified");

    // write out the library source files to be compiled/interpreted
    // with the user's build description
    writeSrcFiles(output, options);

    if(options.isJsonBuild) {
        immutable haveToReturn = jsonBuild(options);
        if(haveToReturn) return;
    }

    maybeCreateReggaefile(options);
    createBuild(output, options);
}

//get JSON description of the build from a scripting language
//and transform it into a build description
//return true if no D files are present
bool jsonBuild(Options options) {
    immutable jsonOutput = getJsonOutput(options);
    return jsonBuild(options, jsonOutput);
}

//transform JSON description into a Build struct
//return true if no D files are present
bool jsonBuild(Options options, in string jsonOutput) {
    enforce(options.backend != Backend.binary, "Binary backend not supported via JSON");

    version(minimal)
        assert(0, "JSON builds not supported in minimal version");
    else {
        import reggae.json_build;
        import reggae.buildgen;
        import reggae.rules.common: Language;

        auto build = jsonToBuild(options.projectPath, jsonOutput);
        doBuild(build, jsonToOptions(options, jsonOutput));

        //true -> exit early
        return !build.targets.canFind!(a => a.getLanguage == Language.D);
    }
}


private string getJsonOutput(in Options options) @safe {
    const args = getJsonOutputArgs(options);
    const path = environment.get("PATH", "").split(":");
    const pythonPaths = environment.get("PYTHONPATH", "").split(":");
    const nodePaths = environment.get("NODE_PATH", "").split(":");
    const luaPaths = environment.get("LUA_PATH", "").split(";");
    const srcDir = buildPath(options.workingDir, hiddenDir, "src");
    const binDir = buildPath(srcDir, "reggae");
    auto env = ["PATH": (path ~ binDir).join(":"),
                "PYTHONPATH": (pythonPaths ~ srcDir).join(":"),
                "NODE_PATH": (nodePaths ~ options.projectPath).join(":"),
                "LUA_PATH": (luaPaths ~ buildPath(options.projectPath, "?.lua")).join(";")];
    immutable res = execute(args, env);
    enforce(res.status == 0, text("Could not execute ", args.join(" "), ":\n", res.output));
    return res.output;
}

private string[] getJsonOutputArgs(in Options options) @safe {
    final switch(options.reggaeFileLanguage) {

    case BuildLanguage.D:
        assert(0, "Cannot obtain JSON build for builds written in D");

    case BuildLanguage.Python:

        auto optionsString = () @trusted {
            import std.json;
            import std.traits;
            JSONValue jsonVal = parseJSON(`{}`);
            foreach(member; __traits(allMembers, typeof(options))) {
                static if(is(typeof(mixin(`options.` ~ member)) == const(Backend)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(bool)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string[string])) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string[])))
                    jsonVal.object[member] = mixin(`options.` ~ member);
            }
            return jsonVal.toString;
        }();

        return ["/usr/bin/env", "python", "-m", "reggae.reggae_json_build",
                "--options", optionsString,
                options.projectPath];

    case BuildLanguage.Ruby:
        return ["ruby", "-S",
                "-I" ~ options.projectPath,
                "-I" ~ buildPath(options.workingDir, hiddenDir, "src", "reggae"),
                "reggae_json_build.rb"];

    case BuildLanguage.Lua:
        return ["reggae_json_build.lua"];

    case BuildLanguage.JavaScript:
        return ["reggae_json_build.js"];
    }
}

enum coreFiles = [
    "options.d",
    "buildgen_main.d", "buildgen.d",
    "build.d",
    "backend/package.d", "backend/binary.d",
    "package.d", "range.d", "reflect.d",
    "dependencies.d", "types.d", "dcompile.d",
    "ctaa.d", "sorting.d", "file.d",
    "rules/package.d",
    "rules/common.d",
    "rules/d.d",
    "rules/c_and_cpp.d",
    "core/package.d", "core/rules/package.d",
    ];
enum otherFiles = [
    "backend/ninja.d", "backend/make.d", "backend/tup.d",
    "dub/info.d", "rules/dub.d",
    ];

version(minimal) {
    enum string[] foreignFiles = [];
} else {
    enum foreignFiles = [
        "__init__.py", "build.py", "reggae_json_build.py", "reflect.py", "rules.py",
        "reggae.rb", "reggae_json_build.rb",
        ];
}

//all files that need to be written out and compiled
private string[] fileNames() @safe pure nothrow {
    version(minimal)
        return coreFiles;
    else
        return coreFiles ~ otherFiles;
}


private void createBuild(T)(T output, in Options options) {

    enforce(options.reggaeFilePath.exists, text("Could not find ", options.reggaeFilePath));

    //compile the binaries (the build generator and dcompile)
    immutable buildGenName = compileBinaries(output, options);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;

    //only got here to build .dcompile
    if(options.isScriptBuild) return;

    //actually run the build generator
    output.writeln("[Reggae] Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(options.workingDir, hiddenDir, buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    output.writeln(retRunBuildgen.output);
}


struct Binary {
    string name;
    const(string)[] cmd;
}


private string compileBinaries(T)(T output, in Options options) {
    buildDCompile(output, options);

    immutable buildGenName = getBuildGenName(options);
    if(options.isScriptBuild) return buildGenName;

    const buildGenCmd = getCompileBuildGenCmd(options);
    immutable buildObjName = "build.o";
    buildBinary(output, options, Binary(buildObjName, buildGenCmd));

    const reggaeFileDeps = getReggaeFileDependencies;
    auto objFiles = [buildObjName];
    if(!reggaeFileDeps.empty) {
        immutable rest = "rest.o";
        buildBinary(output,
                    options,
                    Binary(rest,
                           ["dmd",
                            "-c",
                            "-of" ~ "rest.o"] ~
                           importPaths(options) ~
                           reggaeFileDeps));
        objFiles ~= rest;
    }
    buildBinary(output, options, Binary(buildGenName, ["dmd", "-of" ~ buildGenName] ~ objFiles));

    return buildGenName;
}

void buildDCompile(T)(T output, in Options options) {
    immutable name = "dcompile";

    if(!thisExePath.newerThan(name)) return;

    immutable cmd = ["dmd",
                     "-Isrc",
                     "-of" ~ name,
                     buildPath(options.workingDir, hiddenDir, reggaeSrcRelDirName, "dcompile.d"),
                     buildPath(options.workingDir, hiddenDir, reggaeSrcRelDirName, "dependencies.d")];

    buildBinary(output, options, Binary(name, cmd));
}

private bool isExecutable(in char[] path) @trusted nothrow @nogc //TODO: @safe
{
    import core.sys.posix.unistd;
    import std.internal.cstring;
    return (access(path.tempCString(), X_OK) == 0);
}

private void buildBinary(T)(T output, in Options options, in Binary bin) {
    import std.process;
    string[string] env;
    auto config = Config.none;
    auto maxOutput = size_t.max;
    auto workDir = buildPath(options.workingDir, hiddenDir);
    std.stdio.write("[Reggae] Compiling metabuild binary ", bin.name);
    if(options.verbose) std.stdio.write(" with ", bin.cmd.join(" "));
    output.writeln;
    // std.process.execute has a bug where using workDir and a relative path
    // don't work (https://issues.dlang.org/show_bug.cgi?id=15915)
    // so executeShell is used instead
    immutable res = executeShell(bin.cmd.join(" "), env, config, maxOutput, workDir);
    enforce(res.status == 0, text("Couldn't execute ", bin.cmd.join(" "), "\nin ", workDir,
                                  ":\n", res.output,
                                  "\n", "bin.name: ", bin.name, ", bin.cmd: ", bin.cmd.join(" ")));

}


private const(string)[] getCompileBuildGenCmd(in Options options) @safe {
    import reggae.rules.common: objExt;

    const reggaeSrcs = ("config.d" ~ fileNames).
        filter!(a => a != "dcompile.d").
        map!(a => buildPath(reggaeSrcRelDirName, a)).array;

    immutable buildBinFlags = options.backend == Backend.binary
        ? ["-O", "-inline"]
        : [];
    const commonBefore = ["./dcompile",
                          "--objFile=" ~ "build.o",
                          "--depFile=" ~ "reggaefile.dep",
                          "dmd"] ~
        importPaths(options) ~
        ["-g",
         "-debug"];
    const commonAfter = buildBinFlags ~
        options.reggaeFilePath ~ reggaeSrcs;
    version(minimal) return commonBefore ~ "-version=minimal" ~ commonAfter;
    else return commonBefore ~ commonAfter;
}

private string[] importPaths(in Options options) @safe nothrow {
    import std.file;

    immutable srcDir = "-I" ~ buildPath("src");
    // if compiling phobos, the includes for the reggaefile.d compilation
    // will pick up the new phobos if we include the src path
    return "std".exists ? [srcDir] : ["-I" ~ options.projectPath, srcDir];
}

private string getBuildGenName(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? buildPath("..", "build") : "buildgen";
}


immutable reggaeSrcRelDirName = buildPath("src", "reggae");

string reggaeSrcDirName(in Options options) @safe pure nothrow {
    return buildPath(options.workingDir, hiddenDir, reggaeSrcRelDirName);
}


void writeSrcFiles(T)(T output, in Options options) {
    output.writeln("[Reggae] Writing reggae source files");

    import std.file: mkdirRecurse;
    immutable reggaeSrcDirName = reggaeSrcDirName(options);
    if(!reggaeSrcDirName.exists) {
        mkdirRecurse(reggaeSrcDirName);
        mkdirRecurse(buildPath(reggaeSrcDirName, "dub"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "rules"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "backend"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "core", "rules"));
    }

    //this foreach has to happen at compile time due
    //to the string import below.
    foreach(fileName; aliasSeqOf!(fileNames ~ foreignFiles)) {
        auto file = File(reggaeSrcFileName(options, fileName), "w");
        file.write(import(fileName));
    }

    writeConfig(options);
}


private void writeConfig(in Options options) {
    auto file = File(reggaeSrcFileName(options, "config.d"), "w");

    file.writeln(q{
module reggae.config;
import reggae.ctaa;
import reggae.types;
import reggae.options;
    });

    version(minimal) file.writeln("enum isDubProject = false;");
    file.writeln("immutable options = ", options, ";");

    file.writeln("enum userVars = AssocList!(string, string)([");
    foreach(key, value; options.userVars) {
        file.writeln("assocEntry(`", key, "`, `", value, "`), ");
    }
    file.writeln("]);");

    try {
        writeDubConfig(options, file);
    } catch(Exception ex) {
        stderr.writeln("Could not get dub configuration, try 'dub upgrade'");
        throw ex;
    }
}


private string reggaeSrcFileName(in Options options, in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName(options), fileName);
}
