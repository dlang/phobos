import reggae.dependencies;
import std.stdio;
import std.exception;
import std.process;
import std.conv;
import std.algorithm;
import std.getopt;
import std.array;

int main(string[] args) {
    try {
        dcompile(args);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


/**
Only exists in order to get dependencies for each compilation step.
 */
private void dcompile(string[] args) {
    string depFile, objFile;
    auto helpInfo = getopt(args,
                           std.getopt.config.passThrough,
                           "depFile", "The dependency file to write", &depFile,
                           "objFile", "The object file to output", &objFile,
        );
    enforce(args.length >= 2, "Usage: dcompile --objFile <objFile> --depFile <depFile> <compiler> <compiler args>");
    enforce(!depFile.empty && !objFile.empty, "The --depFile and --objFile 'options' are mandatory");
    const compArgs = compilerArgs(args, objFile);
    const fewerArgs = compArgs[0..$-1]; //non-verbose
    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("Could not compile with args:\n", fewerArgs.join(" "), "\n",
                 execute(fewerArgs).output));

    auto file = File(depFile, "w");
    file.write(dependenciesToFile(objFile, dMainDependencies(compRes.output)).join("\n"));
    file.writeln;
}


private string[] compilerArgs(string[] args, in string objFile) @safe pure {
    auto compArgs = args[1 .. $] ~ ["-of" ~ objFile, "-c", "-v"];
    return args[1] == "gdc" ? mapToGdcOptions(compArgs) : compArgs;
}

//takes a dmd command line and maps arguments to gdc ones
private string[] mapToGdcOptions(in string[] compArgs) @safe pure {
    string[string] options = ["-v": "-fd-verbose", "-O": "-O2", "-debug": "-fdebug", "-of": "-o"];

    string doMap(string a) {
        foreach(k, v; options) {
            if(a.startsWith(k)) a = a.replace(k, v);
        }
        return a;
    }

    return compArgs.map!doMap.array;
}
