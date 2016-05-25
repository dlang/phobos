module reggae.dub.info;

import reggae.build;
import reggae.rules;
import reggae.types;
import reggae.config: options;
import reggae.sorting;

public import std.typecons: Yes, No;
import std.typecons: Flag;
import std.algorithm: map, filter, find, splitter;
import std.array: array, join;
import std.path: buildPath;
import std.traits: isCallable;
import std.range: chain;

struct DubPackage {
    string name;
    string path;
    string mainSourceFile;
    string targetFileName;
    string[] flags;
    string[] importPaths;
    string[] stringImportPaths;
    string[] files;
    string targetType;
    string[] versions;
    string[] dependencies;
    string[] libs;
    bool active;
    string[] preBuildCommands;
}

struct DubInfo {
    DubPackage[] packages;

    Target[] toTargets(Flag!"main" includeMain = Yes.main,
                       in string compilerFlags = "",
                       Flag!"allTogether" allTogether = No.allTogether) @safe const {
        Target[] targets;

        foreach(const i, const dubPackage; packages) {
            const importPaths = allImportPaths();
            const stringImportPaths = dubPackage.allOf!(a => a.packagePaths(a.stringImportPaths))(packages);
            auto versions = dubPackage.allOf!(a => a.versions)(packages).map!(a => "-version=" ~ a);
            //the path must be explicit for the other packages, implicit for the "main"
            //package
            const projDir = i == 0 ? "" : dubPackage.path;

            immutable flags = chain(dubPackage.flags, versions, [options.dflags], [compilerFlags]).join(" ");

            const files = dubPackage.files.
                filter!(a => includeMain || a != dubPackage.mainSourceFile).
                map!(a => buildPath(dubPackage.path, a)).array;

            auto func = allTogether ? &dlangPackageObjectFilesTogether : &dlangPackageObjectFiles;
            targets ~= func(files, flags, importPaths, stringImportPaths, projDir);
        }

        return targets;
    }

    //@trusted: array
    Target mainTarget(string compilerFlags = "") @trusted const {
        const pack = packages[0];
        string[] mainLinkerFlags;
        mainLinkerFlags ~= (pack.targetType == "library" || pack.targetType == "staticLibrary") ? ["-lib"] : [];
        mainLinkerFlags ~= linkerFlags();

        return link(ExeName(packages[0].targetFileName),
                    toTargets(Yes.main, compilerFlags),
                    Flags(mainLinkerFlags.join(" ")));
    }

    string[] linkerFlags() @safe const pure nothrow {
        const allLibs = packages.map!(a => a.libs).join;
        return allLibs.map!(a => "-L-l" ~ a).array;
    }

    string[] mainTargetImportPaths() @trusted nothrow const {
        return packages[0].allOf!(a => a.packagePaths(a.importPaths))(packages);
    }

    string[][] fetchCommands() @safe pure nothrow const {
        return packages[0].dependencies.map!(a => ["dub", "fetch", a]).array;
    }

    string[] allImportPaths() @safe nothrow const {
        string[] paths;
        auto rng = packages.map!(a => a.packagePaths(a.importPaths));
        foreach(p; rng) paths ~= p;
        return paths ~ options.projectPath;
    }
}


private auto packagePaths(in DubPackage pack, in string[] paths) @trusted nothrow {
    return paths.map!(a => buildPath(pack.path, a)).array;
}

//@trusted because of map.array
private string[] allOf(alias F)(in DubPackage pack, in DubPackage[] packages) @trusted nothrow {
    string[] paths;
    //foreach(d; [pack.name] ~ pack.dependencies) doesn't compile with CTFE
    //it seems to have to do with constness, replace string[] with const(string)[]
    //and it won't compile
    string[] dependencies = [pack.name];
    dependencies ~= pack.dependencies;
    foreach(dependency; dependencies) {

        import std.range;
        auto depPack = packages.find!(a => a.name == dependency);
        if(!depPack.empty) {
            paths ~= F(depPack.front).array;
        }
    }
    return paths;
}
