
/**
 * C's &lt;process.h&gt;
 * Authors: Walter Bright, Digital Mars, www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCProcess
 */

module std.c.process;

private import std.c.stddef;

extern (C):

void exit(int);
void _c_exit();
void _cexit();
void _exit(int);
void abort();
void _dodtors();
int getpid();

int system(in char *);

enum { _P_WAIT, _P_NOWAIT, _P_OVERLAY };

int execl(in char *, in char *,...);
int execle(in char *, in char *,...);
int execlp(in char *, in char *,...);
int execlpe(in char *, in char *,...);
int execv(in char *, in char **);
int execve(in char *, in char **, in char **);
int execvp(in char *, in char **);
int execvpe(in char *, in char **, in char **);


enum { WAIT_CHILD, WAIT_GRANDCHILD }

int cwait(int *,int,int);
int wait(int *);

version (Windows)
{
    uint _beginthread(void function(void *),uint,void *);

    extern (Windows) alias uint function (void *) stdfp;

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


