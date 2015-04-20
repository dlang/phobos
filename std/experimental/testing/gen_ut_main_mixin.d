/**
This module implements a $(LINK2 http://dlang.org/template-mixin.html,
template mixin) containing a program to search a list of directories
for all .d files therein, then writes a D program to run all unit
tests in those files using std.experimental.testing. The program
implemented by this mixin only writes out a D file that itself must be
compiled and run.

To use this as a runnable program, simply mix in and compile:
-----
#!/usr/bin/rdmd
import std.experimental.testing;
mixin genUtMain;
-----

Or just use rdmd with the included
$(LINK2 std_experimental_testing_gen_ut_main.html, $(D gen_ut_main.d))
which does the above. The examples below use the second option.

By default, genUtMain will look for unit tests in a $(D tests)
folder and write a program out to a file named $(D ut.d). To change
the file to write to, use the $(D -f) option. To change what
directories to look in, simply pass them in as the remaining
command-line arguments.

Examples:
-----
# write ut.d that finds unit tests from files in the tests directory
rdmd $PHOBOS/std/experimental/testing/gen_ut_main.d

# write foo.d that finds unit tests from the src and other directories
rdmd $PHOBOS/std/experimental/testing/gen_ut_main.d -f foo.d src other
-----

The resulting $(D ut.d) file (or as named by the $(D -f) option) is
also a program that must be compiled and, when run, will run the unit
tests found. By default, it will run all tests. To run one test or
all tests in a particular package, pass them in as command-line arguments.
The $(D -h) option will list all command-line options.

Examples (assuming the generated file is called $(D ut.d)):
-----
rdmd -unittest ut.d # run all tests
rdmd -unittest ut.d tests.foo tests.bar # run all tests from these packages
rdmd ut.d -h # list command-line options
-----
*/

module std.experimental.testing.gen_ut_main_mixin;

mixin template genUtMain() {

    import std.stdio;
    import std.array : replace, array, join;
    import std.conv : to;
    import std.algorithm : map;
    import std.string: strip;
    import std.exception : enforce;
    import std.file : exists, DirEntry, dirEntries, isDir, SpanMode;
    import std.path : buildNormalizedPath;

    int main(string[] args)
    {
        try
        {
            const options = getOptions(args);

            if (options.help || options.showVersion)
            {
                return 0;
            }

            writeFile(options, findModuleNames(options.dirs));
            return 0;
        }
        catch(Exception ex)
        {
            stderr.writeln(ex.msg);
            return 1;
        }
    }

    private struct Options
    {
        bool verbose;
        string fileName;
        string[] dirs;
        bool help;
        bool showVersion;
    }

    private Options getOptions(string[] args)
    {
        import std.getopt;

        Options options;
        auto getOptRes = getopt(
            args,
            "verbose|v", "Verbose mode.", &options.verbose,
            "file|f", "The filename to write. Will use a temporary if not set.", &options.fileName,
            "version", "Show version.", &options.showVersion,
        );

        if (getOptRes.helpWanted)
        {
            defaultGetoptPrinter("Usage: gen_ut_main [options] [testDir1] [testDir2]...", getOptRes.options);
            options.help = true;
            return options;
        }

        if (options.showVersion)
        {
            writeln("gen_ut_main version v0.2.5");
            return options;
        }

        if (!options.fileName)
        {
            options.fileName = "ut.d";
        }

        options.dirs = args.length <= 1 ? ["tests"] : args[1 .. $];

        if (options.verbose)
        {
            writeln(__FILE__, ": finding all test cases in ", options.dirs);
        }

        return options;
    }


    DirEntry[] findModuleEntries(in string[] dirs)
    {

        DirEntry[] modules;
        foreach (dir; dirs)
        {
            enforce(isDir(dir), dir ~ " is not a directory name");
            auto entries = dirEntries(dir, "*.d", SpanMode.depth);
            auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a.name)));
            modules ~= normalised.array;
        }

        return modules;
    }

    string[] findModuleNames(in string[] dirs)
    {
        import std.path : dirSeparator;

        //cut off extension
        return findModuleEntries(dirs).
            map!(a => replace(a.name[0 .. $ - 2], dirSeparator, ".")).
            array;
    }

    private auto writeFile(in Options options, in string[] modules)
    {
        if(!haveToUpdate(options, modules))
        {
            writeln("Not writing to ", options.fileName, ": no changes detected");
            return;
        }

        writeln("Writing to unit test main file ", options.fileName);
        writeln("Do not forget to use -unittest when executing ", options.fileName);

        auto wfile = File(options.fileName, "w");
        wfile.write(modulesDbList(modules));
        wfile.writeln(q{
//Automatically generated by std.experimental.testing.gen_ut_main, do not edit by hand.
import std.stdio;
import std.experimental.testing;

            });

        wfile.writeln("int main(string[] args)");
        wfile.writeln("{");
        wfile.writeln(`    writeln("\nAutomatically generated file ` ~
                      options.fileName.replace("\\", "\\\\") ~ `");`);
        wfile.writeln("    writeln(`Running unit tests from dirs " ~ options.dirs.to!string ~ "`);");

        immutable indent = "                     ";
        wfile.writeln("    return runTests!(\n" ~
                      modules.map!(a => indent ~ `"` ~ a ~ `"`).join(",\n") ~
                      "\n" ~ indent ~ ")\n" ~ indent ~ "(args);");
        wfile.writeln("}");
        wfile.close();
    }


    private bool haveToUpdate(in Options options, in string[] modules)
    {
        if (!options.fileName.exists)
        {
            return true;
        }

        auto file = File(options.fileName);
        return file.readln.strip != modulesDbList(modules);
    }


    //used to not update the file if the file list hasn't changed
    private string modulesDbList(in string[] modules) @safe pure nothrow
    {
        return "//" ~ modules.join(",");
    }
}
