module reggae.rules.c_and_cpp;

import reggae.build;
import reggae.rules.common;
import reggae.types;
import std.range;
import std.traits;
import std.stdio;
import std.file;

@safe:

Target unityBuild(ExeName exeName,
                  alias sourcesFunc,
                  Flags flags = Flags(),
                  IncludePaths includes = IncludePaths(),
                  alias dependenciesFunc = emptyTargets,
                  alias implicitsFunc = emptyTargets)() @trusted {

    import std.path;
    import reggae.config: options;

    const srcFiles = sourcesToFileNames!(sourcesFunc);

    immutable dirName = buildPath(options.workingDir, topLevelDirName(Target(exeName.value)));
    dirName.exists || mkdirRecurse(dirName);

    immutable fileName = buildPath(dirName, "unity.cpp");
    auto unityFile = File(fileName, "w");

    unityFile.writeln(unityFileContents(options.projectPath, srcFiles));

    return unityTarget(exeName, options.projectPath, srcFiles, flags, includes,
                       dependenciesFunc(), implicitsFunc());
}



/**
 Returns the contents of the unity build file for these source files.
 The source files have to all be in the same language and the only
 supported languages are C and C++
 */
string unityFileContents(in string projectPath, in string[] files) pure {
    import std.array;
    import std.algorithm;
    import std.path;

    if(files.empty)
        throw new Exception("Cannot perform a unity build with no files");

    immutable languages = files.map!getLanguage.array;

    if(!languages.all!(a => a == Language.C) && !languages.all!(a => a == Language.Cplusplus))
        throw new Exception("Unity build can only be done if all files are C or C++");


    return files.map!(a => `#include "` ~ buildPath(projectPath, a) ~ `"`).join("\n");
}


/**
 Returns the unity build target for these parameters.
 */
Target unityTarget(ExeName exeName,
                   string projectPath,
                   string[] srcFiles,
                   Flags flags = Flags(),
                   IncludePaths includes = IncludePaths(),
                   alias dependenciesFunc = emptyTargets,
                   alias implicitsFunc = emptyTargets,
    )() {
    return unityTarget(exeName, projectPath, srcFiles, flags, includes, dependenciesFunc());
}

Target unityTarget(R1, R2)(in ExeName exeName,
                           in string projectPath,
                           in string[] srcFiles,
                           in Flags flags = Flags(),
                           in IncludePaths includes = IncludePaths(),
                           R1 dependencies = emptyTargets(),
                           R2 implicits = emptyTargets(),

    )
    pure if(isInputRange!R1 && is(ElementType!R1 == Target) && isInputRange!R2 && is(ElementType!R2 == Target)) {

    import std.algorithm;
    import std.path;

    auto justFileName = srcFiles.map!getLanguage.front == Language.C ? "unity.c" : "unity.cpp";
    auto unityFileName = buildPath(gBuilddir, topLevelDirName(Target(exeName.value)), justFileName);
    auto command = compileCommand(unityFileName,
                                   flags.value,
                                   includes.value,
                                   [],
                                   projectPath,
                                   No.justCompile);
    auto unityFileTarget = Target.phony(unityFileName, "", [], srcFiles.map!(a => Target(a)).array);
    return Target(exeName.value, command, unityFileTarget ~ dependencies.array);
}


private Target[] emptyTargets() {
    return [];
}
