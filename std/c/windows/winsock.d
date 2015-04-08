/*
    Written by Christopher E. Miller
    Placed into public domain.
*/


/// Please import core.sys.windows.winsock2 instead.This module will be deprecated in DMD 2.068.
module std.c.windows.winsock;

version (Windows):
public import core.sys.windows.winsock2;
