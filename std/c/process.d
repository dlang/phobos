// @@@DEPRECATED_2017-06@@@

/**
 * $(RED Deprecated. Use $(D core.stdc.stdlib) or the appropriate
 *       core.sys.posix.* modules instead. This module will be removed in June
 *       2017.)
 *
 * C's &lt;process.h&gt;
 * Authors: Walter Bright, Digital Mars, www.digitalmars.com
 * License: Public Domain
 */
deprecated("Import core.stdc.stdlib or the appropriate core.sys.posix.* modules instead")
module std.c.process;

import core.stdc.stddef;
public import core.stdc.stdlib : exit, abort, system;

extern (C):

//These declarations are not defined or used elsewhere.
void _c_exit();
void _cexit();
void _dodtors();
int getpid();
enum { WAIT_CHILD, WAIT_GRANDCHILD }
int cwait(int *,int,int);
int wait(int *);
int execlpe(in char *, in char *,...);

//These constants are undefined elsewhere and only used in the deprecated part
//of std.process.
enum { _P_WAIT, _P_NOWAIT, _P_OVERLAY }

//These declarations are defined for Posix in core.sys.posix.unistd but unused
//from here.
void _exit(int);
int execl(in char *, in char *,...);
int execle(in char *, in char *,...);
int execlp(in char *, in char *,...);

//All of these except for execvpe are defined for Posix in core.sys.posix.unistd
//and only used in the old part of std.process.
int execv(in char *, in char **);
int execve(in char *, in char **, in char **);
int execvp(in char *, in char **);
int execvpe(in char *, in char **, in char **);

//All these Windows declarations are not publicly defined elsewhere and only
//spawnvp is used once in a deprecated function in std.process.
version (Windows)
{
    uint _beginthread(void function(void *),uint,void *);

    extern (Windows) alias stdfp = uint function (void *);

    uint _beginthreadex(void* security, uint stack_size,
            stdfp start_addr, void* arglist, uint initflag,
            uint* thrdaddr);

    void _endthread();
    void _endthreadex(uint);

    int spawnl(int, in char *, in char *,...);
    int spawnle(int, in char *, in char *,...);
    int spawnlp(int, in char *, in char *,...);
    int spawnlpe(int, in char *, in char *,...);
    int spawnv(int, in char *, in char **);
    int spawnve(int, in char *, in char **, in char **);
    int spawnvp(int, in char *, in char **);
    int spawnvpe(int, in char *, in char **, in char **);


    int _wsystem(in wchar_t *);
    int _wspawnl(int, in wchar_t *, in wchar_t *, ...);
    int _wspawnle(int, in wchar_t *, in wchar_t *, ...);
    int _wspawnlp(int, in wchar_t *, in wchar_t *, ...);
    int _wspawnlpe(int, in wchar_t *, in wchar_t *, ...);
    int _wspawnv(int, in wchar_t *, in wchar_t **);
    int _wspawnve(int, in wchar_t *, in wchar_t **, in wchar_t **);
    int _wspawnvp(int, in wchar_t *, in wchar_t **);
    int _wspawnvpe(int, in wchar_t *, in wchar_t **, in wchar_t **);

    int _wexecl(in wchar_t *, in wchar_t *, ...);
    int _wexecle(in wchar_t *, in wchar_t *, ...);
    int _wexeclp(in wchar_t *, in wchar_t *, ...);
    int _wexeclpe(in wchar_t *, in wchar_t *, ...);
    int _wexecv(in wchar_t *, in wchar_t **);
    int _wexecve(in wchar_t *, in wchar_t **, in wchar_t **);
    int _wexecvp(in wchar_t *, in wchar_t **);
    int _wexecvpe(in wchar_t *, in wchar_t **, in wchar_t **);
}


