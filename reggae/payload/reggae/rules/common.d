module reggae.rules.common;


import reggae.build;
import reggae.ctaa;
import reggae.types;
import std.algorithm;
import std.path;
import std.array: array;
import std.traits;
import std.typecons;

/**
 This template function exists so as to be referenced in a reggaefile.d
 at top-level without being called via $(D alias). That way it can be
 named and used in a further $(D Target) definition without the need to
 define a function returning $(D Build).
 This function gets the source files to be compiled at runtime by searching
 for source files in the given directories, adding files and filtering
 as appropriate by the parameters given in $(D sources), its first compile-time
 parameter. The other parameters are self-explanatory.

 This function returns a list of targets that are the result of compiling
 source files written in the supported languages. The $(Sources) function
 can be used to specify source directories and source files, as well as
 a filter function to select those files that are actually wanted.
 */
Target[] objectFiles(alias sourcesFunc = Sources!(),
                     Flags flags = Flags(),
                     ImportPaths includes = ImportPaths(),
                     StringImportPaths stringImports = StringImportPaths(),
    )() @trusted {

    import std.stdio;
    const srcFiles = sourcesToFileNames!(sourcesFunc);
    return srcFilesToObjectTargets(srcFiles, flags, includes, stringImports);
}

@safe:

/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package). The language is determined
 by the file extension of the file passed in.
 The $(D projDir) variable is best left alone; right now only the dub targets
 make use of it (since dub packages are by definition outside of the project
 source tree).
*/
Target objectFile(in SourceFile srcFile,
                  in Flags flags = Flags(),
                  in ImportPaths includePaths = ImportPaths(),
                  in StringImportPaths stringImportPaths = StringImportPaths(),
                  in string projDir = "$project") pure {

    auto cmd = compileCommand(srcFile.value, flags.value, includePaths.value, stringImportPaths.value, projDir);
    return Target(srcFile.value.objFileName, cmd, [Target(srcFile.value)]);
}

/**
 A binary executable. The same as calling objectFiles and link
 with these parameters.
 */
Target executable(ExeName exeName,
                  alias sourcesFunc = Sources!(),
                  Flags compilerFlags = Flags(),
                  ImportPaths includes = ImportPaths(),
                  StringImportPaths stringImports = StringImportPaths(),
                  Flags linkerFlags = Flags())
    () {
    auto objs = objectFiles!(sourcesFunc, compilerFlags, includes, stringImports);
    return link!(exeName, { return objs; }, linkerFlags);
}

Target executable(in string projectPath,
                  in string name,
                  in string[] srcDirs,
                  in string[] excDirs,
                  in string[] srcFiles,
                  in string[] excFiles,
                  in string compilerFlags,
                  in string linkerFlags,
                  in string[] includes,
                  in string[] stringImports)
{
    auto objs = objectFiles(projectPath, srcDirs, excDirs, srcFiles, excFiles, compilerFlags, includes, stringImports);
    return link(ExeName(name), objs, Flags(linkerFlags));
}



/**
 "Compile-time" link function.
 Its parameters are compile-time so that it can be aliased and used
 at global scope in a reggafile.
 Links an executable from the given dependency targets. The linker used
 depends on the file extension of the leaf nodes of the passed-in targets.
 If any D files are found, the linker is the D compiler, and so on with
 C++ and C. If none of those apply, the D compiler is used.
 */
Target link(ExeName exeName, alias dependenciesFunc, Flags flags = Flags())() @safe {
    auto dependencies = dependenciesFunc();
    return link(exeName, dependencies, flags);
}

/**
 Regular run-time link function.
 Links an executable from the given dependency targets. The linker used
 depends on the file extension of the leaf nodes of the passed-in targets.
 If any D files are found, the linker is the D compiler, and so on with
 C++ and C. If none of those apply, the D compiler is used.
 */
Target link(in ExeName exeName, Target[] dependencies, in Flags flags = Flags()) @safe pure {
    auto command = Command(CommandType.link, assocList([assocEntry("flags", flags.value.splitter.array)]));
    return Target(exeName.value, command, dependencies);
}


/**
 Convenience rule for creating static libraries
 */
Target[] staticLibrary(string name,
                       alias sourcesFunc = Sources!(),
                       Flags flags = Flags(),
                       ImportPaths includes = ImportPaths(),
                       StringImportPaths stringImports = StringImportPaths())
    () {

    version(Posix) {}
    else
        static assert(false, "Can only create static libraries on Posix");

    const srcFiles = sourcesToFileNames!(sourcesFunc);
    return [Target(buildPath("$builddir", name),
                   "ar rcs $out $in",
                   objectFiles!(sourcesFunc, flags, includes, stringImports)())];
}

/**
 "Compile-time" target creation.
 Its parameters are compile-time so that it can be aliased and used
 at global scope in a reggaefile
 */
Target target(alias outputs,
              alias command = "",
              alias dependenciesFunc = () { Target[] ts; return ts; },
              alias implicitsFunc = () { Target[] ts; return ts; })() @trusted {

    auto depsRes = dependenciesFunc();
    auto impsRes = implicitsFunc();

    static if(isArray!(typeof(depsRes)))
        auto dependencies = depsRes;
    else
        auto dependencies = [depsRes];

    static if(isArray!(typeof(impsRes)))
        auto implicits = impsRes;
    else
        auto implicits = [impsRes];


    return Target(outputs, command, dependencies, implicits);
}


/**
 * Convenience alias for appending targets without calling any runtime function.
 * This replaces the need to manually define a function to return a `Build` struct
 * just to concatenate targets
 */
Target[] targetConcat(T...)() {
    Target[] ret;
    foreach(target; T) {
        static if(isCallable!target)
            ret ~= target();
        else
            ret ~= target;
    }
    return ret;
}

/**
 Compile-time version of Target.phony
 */
Target phony(string name,
             string shellCommand,
             alias dependenciesFunc = () { Target[] ts; return ts; },
             alias implicitsFunc = () { Target[] ts; return ts; })() {
    return Target.phony(name, shellCommand, arrayify!dependenciesFunc, arrayify!implicitsFunc);
}


//end of rules

private auto arrayify(alias func)() {
    import std.traits;
    auto ret = func();
    static if(isArray!(typeof(ret)))
        return ret;
    else
        return [ret];
}

string[] sourcesToFileNames(alias sourcesFunc = Sources!())() @trusted {

    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath, buildPath;
    import std.array: array;
    import std.traits: isCallable;
    import reggae.config: options;

    auto srcs = sourcesFunc();

    DirEntry[] modules;
    foreach(dir; srcs.dirs.value.map!(a => buildPath(options.projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));

        modules ~= normalised.filter!(a => !a.isDir).array;
    }

    foreach(module_; srcs.files.value) {
        modules ~= DirEntry(buildNormalizedPath(buildPath(options.projectPath, module_)));
    }

    return modules.
        map!(a => a.name.removeProjectPath).
        filter!(srcs.filterFunc).
        filter!(a => a != "reggaefile.d").
        array;
}

//run-time version
string[] sourcesToFileNames(in string projectPath,
                            in string[] srcDirs,
                            in string[] excDirs,
                            in string[] srcFiles,
                            in string[] excFiles) @trusted {



    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath, buildPath;
    import std.array: array;
    import std.traits: isCallable;

    DirEntry[] files;
    foreach(dir; srcDirs.filter!(a => !excDirs.canFind(a)).map!(a => buildPath(projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));

        files ~= normalised.array;
    }

    foreach(module_; srcFiles) {
        files ~= DirEntry(buildNormalizedPath(buildPath(projectPath, module_)));
    }

    return files.
        map!(a => removeProjectPath(projectPath, a.name)).
        filter!(a => !excFiles.canFind(a)).
        filter!(a => a != "reggaefile.d").
        array;
}


//run-time version
Target[] objectFiles(in string projectPath,
                     in string[] srcDirs,
                     in string[] excDirs,
                     in string[] srcFiles,
                     in string[] excFiles,
                     in string flags = "",
                     in string[] includes = [],
                     in string[] stringImports = []) @trusted {

    return srcFilesToObjectTargets(sourcesToFileNames(projectPath, srcDirs, excDirs, srcFiles, excFiles),
                                   Flags(flags),
                                   const ImportPaths(includes),
                                   const StringImportPaths(stringImports));
}

//run-time version
Target[] staticLibrary(in string projectPath,
                       in string name,
                       in string[] srcDirs,
                       in string[] excDirs,
                       in string[] srcFiles,
                       in string[] excFiles,
                       in string flags,
                       in string[] includes,
                       in string[] stringImports) @trusted {


    version(Posix) {}
    else
        static assert(false, "Can only create static libraries on Posix");

    return [Target([buildPath("$builddir", name)],
                   "ar rcs $out $in",
                   objectFiles(projectPath, srcDirs, excDirs, srcFiles, excFiles, flags, includes, stringImports))];
}


private Target[] srcFilesToObjectTargets(in string[] srcFiles,
                                         in Flags flags,
                                         in ImportPaths includes,
                                         in StringImportPaths stringImports) {

    const dSrcs = srcFiles.filter!(a => a.getLanguage == Language.D).array;
    auto otherSrcs = srcFiles.filter!(a => a.getLanguage != Language.D && a.getLanguage != Language.unknown);
    import reggae.rules.d: dlangPackageObjectFiles;
    return dlangPackageObjectFiles(dSrcs, flags.value, ["."] ~ includes.value, stringImports.value) ~
        otherSrcs.map!(a => objectFile(SourceFile(a), flags, includes)).array;

}


version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
}

package string objFileName(in string srcFileName) pure {
    import std.path: stripExtension, defaultExtension, isRooted, stripDrive;
    immutable localFileName = srcFileName.isRooted
        ? srcFileName.stripDrive[1..$]
        : srcFileName;
    return localFileName.stripExtension.defaultExtension(objExt);
}

string removeProjectPath(in string path) {
    import std.path: relativePath, absolutePath;
    import reggae.config: options;
    //relativePath is @system
    return () @trusted { return path.absolutePath.relativePath(options.projectPath.absolutePath); }();
}

string removeProjectPath(in string projectPath, in string path) pure {
    import std.path: relativePath, absolutePath;
    //relativePath is @system
    return () @trusted { return path.absolutePath.relativePath(projectPath.absolutePath); }();
}



Command compileCommand(in string srcFileName,
                       in string flags = "",
                       in string[] includePaths = [],
                       in string[] stringImportPaths = [],
                       in string projDir = "$project",
                       Flag!"justCompile" justCompile = Yes.justCompile) pure {

    string maybeExpand(string path) {
        return path.startsWith(gBuilddir) ? expandBuildDir(path) : buildPath(projDir, path);
    }

    auto includeParams = includePaths.map!(a => "-I" ~ maybeExpand(a)). array;
    auto flagParams = flags.splitter.array;
    immutable language = getLanguage(srcFileName);

    auto params = [assocEntry("includes", includeParams),
                   assocEntry("flags", flagParams)];

    if(language == Language.D)
        params ~= assocEntry("stringImports",
                             stringImportPaths.map!(a => "-J" ~ maybeExpand(a)).array);

    params ~= assocEntry("DEPFILE", [srcFileName.objFileName ~ ".dep"]);

    immutable type = justCompile ? CommandType.compile : CommandType.compileAndLink;
    return Command(type, assocList(params));
}


enum Language {
    C,
    Cplusplus,
    D,
    unknown,
}

Language getLanguage(in string srcFileName) pure nothrow {
    switch(srcFileName.extension) with(Language) {
    case ".d":
        return D;
    case ".cpp":
    case ".CPP":
    case ".C":
    case ".cxx":
    case ".c++":
    case ".cc":
        return Cplusplus;
    case ".c":
        return C;
    default:
        return unknown;
    }
}
