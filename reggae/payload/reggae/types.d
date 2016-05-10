module reggae.types;

import reggae.rules.common: exeExt;
import std.path: baseName, stripExtension, defaultExtension;

//Wrapper structs to ensure type-safety and readability

@safe:

struct SourceFileName {
    string value;
}

struct BinaryFileName {
    string value;
}

struct App {
    SourceFileName srcFileName;
    BinaryFileName exeFileName;

    this(SourceFileName srcFileName) pure {
        immutable stripped = srcFileName.value.baseName.stripExtension;
        immutable exeFileName = BinaryFileName(exeExt == "" ? stripped : stripped.defaultExtension(exeExt));

        this(srcFileName, exeFileName);
    }

    this(SourceFileName srcFileName, BinaryFileName exeFileName) @safe pure nothrow {
        this.srcFileName = srcFileName;
        this.exeFileName = exeFileName;
    }
}


struct Flags {
    string value;
}

struct ImportPaths {
    string[] value;
}

alias IncludePaths = ImportPaths;

struct StringImportPaths {
    string[] value;
}

struct SrcDirs {
    string[] value;
}

struct SrcFiles {
    string[] value;
}

struct ExcludeFiles {
    string[] value;
}

struct ExeName {
    string value;
}

struct Configuration {
    string value = "default";
}

enum Backend {
    none,
    make,
    ninja,
    tup,
    binary,
}


struct Dirs {
    string[] value = ["."];
}

struct Files {
    string[] value;
}

struct Filter(alias F) {
    alias func = F;
}

struct SourcesImpl(alias F) {
    Dirs dirs;
    Files files;
    Filter!F filter;

    alias filterFunc = F;
}

auto Sources(Dirs dirs = Dirs(), Files files = Files(), F = Filter!(a => true))() {
    return SourcesImpl!(F.func)(dirs, files);
}

auto Sources(string[] dirs, Files files = Files(), F = Filter!(a => true))() {
    return Sources!(Dirs(dirs), files, F)();
}

auto Sources(string dir, Files files = Files(), F = Filter!(a => true))() {
    return Sources!([dir], files, F)();
}

struct SourceFile {
    string value;
}
