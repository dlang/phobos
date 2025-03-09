#!/usr/bin/env rdmd
/**
Phobos V3 Build Script

Usage:
  ./build_v3.d [debug,release,unittest]
*/

import std.conv;
import std.datetime;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

int main(string[] args)
{
    int result = 0;

    bool buildUnittest = false;
    bool buildRelease = false;
    if (args.length > 1)
    {
        buildUnittest = args[1] == "unittest";
        buildRelease = args[1] == "release";
    }

    string argFilePath = buildNormalizedPath(getcwd(), "phobosbuildargs.txt");
    auto dFiles = dirEntries(buildNormalizedPath(getcwd(), "phobos"), "*.d", SpanMode.breadth);
    auto argFile = File(argFilePath, "w");

    version(Windows)
    {
        string unittestExecutable = buildNormalizedPath(getcwd(), "unittest.exe");
    }
    else
    {
        string unittestExecutable = buildNormalizedPath(getcwd(), "unittest");
    }

    scope(exit)
    {
        argFile.close();
        remove(argFilePath);

        if (exists(unittestExecutable)) remove(unittestExecutable);
    }

    result = runCommand("dmd --version", getcwd());
    if (result != 0)
    {
        writeln("Compiler Failure.");
        return result;
    }

    writeln("Source files:");
    //Add source file list to args file.
    foreach(dFile; dFiles)
    {
        if (dFile.isDir()) continue;
        argFile.writeln(dFile.name);
        writeln(dFile.name);
    }

    //Add appropriate DMD arguments to the args file.
    argFile.writeln("-od=./lib");
    if (buildUnittest)
    {
        argFile.writeln("-main");
        argFile.writeln("-unittest");
        argFile.writeln("-debug");

        version(Windows)
        {
            argFile.writeln("-of=unittest.exe");
        }
        else
        {
            argFile.writeln("-of=unittest");
        }
    }
    else if (buildRelease)
    {
        argFile.writeln("-release -O");
        argFile.writeln("-lib");
        argFile.writeln("-of=libphobos3");
    }
    else
    {
        argFile.writeln("-debug");
        argFile.writeln("-lib");
        argFile.writeln("-of=libphobos3-debug");
    }

    argFile.flush();
    argFile.close();

    //Run the build.
    result = runCommand("dmd @\"" ~ argFilePath ~ "\"", getcwd());
    if (result != 0)
    {
        writeln("Build failed.");
        return result;
    }
    else
    {
        writeln("Build successful.");
        writeln();
    }

    //Run unittests if built.
    if (buildUnittest)
    {
        writeln("Running tests...");
        result = runCommand(unittestExecutable, getcwd());

        if (result != 0)
        {
            writeln("Tests failed.");
            return result;
        }
        else
        {
            writeln("Tests successful.");
        }
    }

    return result;
}

private int runCommand(string command, string workDir)
{
    auto pid = pipeShell(command, Redirect.all, null, Config.none, workDir);
    int result = wait(pid.pid);
    foreach (line; pid.stdout.byLine) writeln(line);
    foreach (line; pid.stderr.byLine) writeln(line);
    writeln();
    return result;
}
