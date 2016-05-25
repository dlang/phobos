
/**
High-level rules for compiling D files. For a D-only application with
no dub dependencies, $(D scriptlike) should suffice. If the app depends
on dub packages, consult the reggae.rules.dub module instead.
 */

module reggae.rules.d;

import reggae.types;
import reggae.build;
import reggae.sorting;
import reggae.dependencies: dMainDepSrcs;
import reggae.rules.common;
import std.algorithm;
import std.array;



//generate object file(s) for a D package. By default generates one per package,
//if reggae.config.perModule is true, generates one per module
Target[] dlangPackageObjectFiles(in string[] srcFiles, in string flags = "",
                                 in string[] importPaths = [], in string[] stringImportPaths = [],
                                 in string projDir = "$project") @safe {
    import reggae.config: options;
    auto func = options.perModule ? &dlangPackageObjectFilesPerModule : &dlangPackageObjectFilesPerPackage;
    return func(srcFiles, flags, importPaths, stringImportPaths, projDir);
}

Target[] dlangPackageObjectFilesPerPackage(in string[] srcFiles,
                                           in string flags = "",
                                           in string[] importPaths = [],
                                           in string[] stringImportPaths = [],
                                           in string projDir = "$project")
    @trusted pure {

    if(srcFiles.empty) return [];
    auto command(in string[] files) {
        return compileCommand(files[0].packagePath ~ ".d",
                              flags,
                              importPaths,
                              stringImportPaths,
                              projDir);
    }
    return srcFiles.byPackage.map!(a => Target(a[0].packagePath.objFileName,
                                               command(a),
                                               a.map!(a => Target(a)).array)).array;
}

Target[] dlangPackageObjectFilesPerModule(in string[] srcFiles, in string flags = "",
                                          in string[] importPaths = [], in string[] stringImportPaths = [],
                                          in string projDir = "$project") @trusted pure {
    return srcFiles.map!(a => objectFile(const SourceFile(a),
                                         const Flags(flags),
                                         const ImportPaths(importPaths),
                                         const StringImportPaths(stringImportPaths),
                                         projDir)).array;
}

// compiles all source files in one go
Target[] dlangPackageObjectFilesTogether(in string[] srcFiles, in string flags = "",
                                         in string[] importPaths = [], in string[] stringImportPaths = [],
                                         in string projDir = "$project") @trusted pure {

    if(srcFiles.empty) return [];
    auto command = compileCommand(srcFiles[0], flags, importPaths, stringImportPaths, projDir);
    return [Target(srcFiles[0].packagePath.objFileName, command, srcFiles.map!(a => Target(a)).array)];
}


/**
 Currently only works for D. This convenience rule builds a D scriptlike, automatically
 calculating which files must be compiled in a similar way to rdmd.
 All paths are relative to projectPath.
 This template function is provided as a wrapper around the regular runtime version
 below so it can be aliased without trying to call it at runtime. Basically, it's a
 way to use the runtime scriptlike without having define a function in reggaefile.d,
 i.e.:
 $(D
 alias myApp = scriptlike!(...);
 mixin build!(myApp);
 )
 vs.
 $(D
 Build myBuld() { return scriptlike(..); }
 )
 */
Target scriptlike(App app,
                  Flags flags = Flags(),
                  ImportPaths importPaths = ImportPaths(),
                  StringImportPaths stringImportPaths = StringImportPaths(),
                  alias linkWithFunction = () { return cast(Target[])[];})
    () @trusted {
    auto linkWith = linkWithFunction();
    import reggae.config: options;
    return scriptlike(options.projectPath, app, flags, importPaths, stringImportPaths, linkWith);
}


//regular runtime version of scriptlike
//all paths relative to projectPath
//@trusted because of .array
Target scriptlike(in string projectPath,
                  in App app, in Flags flags,
                  in ImportPaths importPaths,
                  in StringImportPaths stringImportPaths,
                  Target[] linkWith) @trusted {

    import std.path;

    if(getLanguage(app.srcFileName.value) != Language.D)
        throw new Exception("'scriptlike' rule only works with D files");

    auto mainObj = objectFile(SourceFile(app.srcFileName.value), flags, importPaths, stringImportPaths);
    const output = runDCompiler(projectPath, buildPath(projectPath, app.srcFileName.value), flags.value,
                                importPaths.value, stringImportPaths.value);

    const files = dMainDepSrcs(output).map!(a => a.removeProjectPath).array;
    auto dependencies = [mainObj] ~ dlangPackageObjectFiles(files, flags.value,
                                                             importPaths.value, stringImportPaths.value);

    return link(ExeName(app.exeFileName.value), dependencies ~ linkWith);
}


//@trusted because of splitter
private auto runDCompiler(in string projectPath,
                          in string srcFileName,
                          in string flags,
                          in string[] importPaths,
                          in string[] stringImportPaths) @trusted {

    import std.process: execute;
    import std.exception: enforce;
    import std.conv:text;

    immutable compiler = "dmd";
    const compArgs = [compiler] ~ flags.splitter.array ~
        importPaths.map!(a => "-I" ~ buildPath(projectPath, a)).array ~
        stringImportPaths.map!(a => "-J" ~ buildPath(projectPath, a)).array ~
        ["-o-", "-v", "-c", srcFileName];
    const compRes = execute(compArgs);
    enforce(compRes.status == 0, text("scriptlike could not run ", compArgs.join(" "), ":\n", compRes.output));
    return compRes.output;
}
