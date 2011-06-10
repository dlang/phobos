import std.file;
import std.process;
import std.stdio;
import std.string;

version(Posix)
{
    import core.sys.posix.signal;
}


void main(string[] args)
{
    // Allow different path to dmd, or different compiler.
    immutable compiler = args.length == 1 ? "dmd" : args[1];

    immutable string src = "deleteme.d";
    version(Windows)
        immutable string exe = "./deleteme.exe";
    else
        immutable string exe = "./deleteme";

    void compile(string code, string libs = null)
    {
        // Write and compile
        std.file.write(src, code);
        string compile = compiler~" "~src~(libs.length>0 ? " "~libs : "");
        auto result = shell(compile);
        if (result.status != 0)
        {
            stderr.writeln(result.output);
            throw new Exception("Failed compilation: "~compile);
        }
    }

    void ok()
    {
        static int i = 0;
        ++i;
        writeln(i, " OK");
    }
    
    void pok()
    {
        static int i = 0;
        ++i;
        writeln("P", i, " OK");
    }


    Pid pid;


    // Test 1:  Start a process that returns normally.
    compile(q{
        void main() { }
    });
    assert (wait(spawnProcess(exe)) == 0);
    ok();


    // Test 2:  Start a process that returns a nonzero exit code.
    compile(q{
        int main() { return 123; }
    });
    pid = spawnProcess(exe);
    assert (wait(pid) == 123);
    assert (wait(pid) == 123);  // Check that value is cached correctly
    ok();


    // Test 3:  Supply arguments.
    compile(q{
        int main(string[] args)
        {
            if (args.length == 3 && args[1] == "hello" && args[2] == "world")
                return 0;
            return 1;
        }
    });
    assert (wait(spawnProcess(exe, ["hello", "world"])) == 0);
    assert (wait(spawnProcess(exe~" hello world")) == 0);
    ok();


    // Test 4: Supply environment variables.
    compile(q{
        import core.stdc.stdlib;
        import std.conv;
        int main()
        {
            if (to!string(getenv("PATH")).length > 0)  return 1;
            if (to!string(getenv("hello")) != "world")  return 2;
            return 0;
        }
    });
    string[string] env;
    env["hello"] = "world";
    assert (wait(spawnProcess(exe, null, env)) == 0);
    assert (wait(spawnProcess(exe, env)) == 0);
    ok();


    // Test 5: Redirect input.
    compile(q{
        import std.stdio, std.string;
        int main()
        {
            if (stdin.readln().chomp() == "hello world") return 0;
            return 1;
        }
    });
    auto pipe5 = Pipe.create();
    pid = spawnProcess(exe, pipe5.readEnd);
    pipe5.writeEnd.writeln("hello world");
    assert (wait(pid) == 0);
    pipe5.close();
    ok();


    // Test 6: Redirect output and error.
    compile(q{
        import std.stdio;
        void main()
        {
            stdout.write("hello output");
            stderr.write("hello error");
        }
    });
    auto pipe6o = Pipe.create();
    auto pipe6e = Pipe.create();
    pid = spawnProcess(exe, stdin, pipe6o.writeEnd, pipe6e.writeEnd);
    assert (pipe6o.readEnd.readln().chomp() == "hello output");
    assert (pipe6e.readEnd.readln().chomp() == "hello error");
    wait(pid);
    ok();


    // Test 7: Test execute().
    compile(q{
        import std.stdio;
        int main(string[] args)
        {
            stdout.write("hello world");
            return args.length;
        }
    });
    string out7;
    auto ret7 = execute(exe~" foo");
    assert (ret7.status == 2  &&  ret7.output == "hello world");
    ret7 = execute(exe, ["foo", "bar"]);
    assert (ret7.status == 3  &&  ret7.output == "hello world");
    ok();


    // Test 8: Test shell().
    auto ret8 = shell("echo foo");
    assert (ret8.status == 0  &&  ret8.output.chomp() == "foo");
    ok();


version (Posix)
{
    // POSIX test 1: Terminate by signal.
    compile(q{
        void main() { while(true) { } }
    });
    pid = spawnProcess(exe);
    kill(pid.processID, SIGTERM);
    assert (wait(pid) == -SIGTERM);
    pok();


    // POSIX test 2: Pseudo-test of path-searching algorithm.
    auto pipeX = Pipe.create();
    pid = spawnProcess("ls -l", stdin, pipeX.writeEnd);
    bool found = false;
    foreach (line; pipeX.readEnd.byLine())
    {
        if (line.indexOf("deleteme.d") >= 0)  found = true;
    }
    assert (wait(pid) == 0);
    assert (found == true);
    pok();
}

    
    // Clean up.
    std.file.remove(exe);
    std.file.remove(src);
    version(Posix) std.file.remove("deleteme.o");
    version(Windows)
    {
        std.file.remove("deleteme.obj");
        std.file.remove("deleteme.map");
    }
}


