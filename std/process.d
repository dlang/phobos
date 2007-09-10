
/*
 *  Copyright (C) 2003-2004 by Digital Mars, www.digitalmars.com
 *  Written by Matthew Wilson and Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */


module std.process;

private import std.c.stdlib;
private import std.string;
private import std.c.process;

int system(char[] command)
{
    return std.c.process.system(toStringz(command));
}

private void toAStringz(char[][] a, char**az)
{
    foreach(char[] s; a)
    {
	*az++ = toStringz(s);
    }
    *az = null;
}

int execv(char[] pathname, char[][] argv)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);
    return std.c.process.execv(toStringz(pathname), argv_);
}

int execve(char[] pathname, char[][] argv, char[][] envp)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
    char** envp_ = cast(char**)alloca((char*).sizeof * (1 + envp.length));


    toAStringz(argv, argv_);
    toAStringz(envp, envp_);
    return std.c.process.execve(toStringz(pathname), argv_, envp_);
}

int execvp(char[] pathname, char[][] argv)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
    toAStringz(argv, argv_);
    return std.c.process.execvp(toStringz(pathname), argv_);
}

int execvpe(char[] pathname, char[][] argv, char[][] envp)
{
    char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
    char** envp_ = cast(char**)alloca((char*).sizeof * (1 + envp.length));
    toAStringz(argv, argv_);
    toAStringz(envp, envp_);
    return std.c.process.execvpe(toStringz(pathname), argv_, envp_);
}

/* ////////////////////////////////////////////////////////////////////////// */

version(MainTest)
{
    int main(char[][] args)
    {
//	int i = execv(args[1], args[2 .. args.length]);
	int i = execvp(args[1], args[2 .. args.length]);

	printf("exec??() has returned! Error code: %d; errno: %d\n", i, /* errno */0);

	return 0;
    }
}
