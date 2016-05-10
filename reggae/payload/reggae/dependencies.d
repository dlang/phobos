module reggae.dependencies;

import std.regex;
import std.range;


string[] dependenciesFromFile(R)(R lines) if(isInputRange!R) {
    auto arr = lines.array;
    return arr.length < 2 ? [] : arr[1].split(" ");
}


@safe:


/**
 * Given the output of compiling a file, return
 * the list of D files to compile to link the executable
 * Includes all dependencies, not just source files to
 * compile.
 */
string[] dMainDependencies(in string output) {
    string[] dependencies = dMainDepSrcs(output);
    auto fileReg = regex(`^file +([^\t]+)\t+\((.+)\)$`);
    foreach(line; output.split("\n")) {
        auto fileMatch = line.matchFirst(fileReg);
        if(fileMatch) dependencies ~= fileMatch.captures[2];
    }

    return dependencies;
}



/**
 * Given the output of compiling a file, return
 * the list of D files to compile to link the executable.
 * Only includes source files to compile
 */
string[] dMainDepSrcs(in string output) {
    string[] dependencies;
    auto importReg = regex(`^import +([^\t]+)[\t\s]+\((.+)\)$`);
    auto stdlibReg = regex(`^(std\.|core\.|etc\.|object$)`);
    foreach(line; output.split("\n")) {
        auto importMatch = line.matchFirst(importReg);
        if(importMatch) {
            auto stdlibMatch = importMatch.captures[1].matchFirst(stdlibReg);
            if(!stdlibMatch) {
                dependencies ~= importMatch.captures[2];
            }
        }
    }

    return dependencies;
}


string[] dependenciesToFile(in string objFile, in string[] deps) pure nothrow {
    import std.array;
    return [objFile ~ ": \\",
            deps.join(" "),
        ];
}
