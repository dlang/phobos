
// Copyright (c) 2003 by Digital Mars
// All Rights Reserved
// www.digitalmars.com


module std.process;

private import std.string;
private import std.c.process;

int system(char[] command)
{
    return std.c.process.system(toStringz(command));
}
