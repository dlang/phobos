
/* Interface to the C header file process.h
 */

module std.c.process;

extern (C):

void exit(int);
void _c_exit();
void _cexit();
void _exit(int);
void abort();
void _dodtors();
int getpid();

int system(char *);

int spawnl(int, char *, char *,...);
int spawnle(int, char *, char *,...);
int spawnlp(int, char *, char *,...);
int spawnlpe(int, char *, char *,...);
int spawnv(int, char *, char **);
int spawnve(int, char *, char **, char **);
int spawnvp(int, char *, char **);
int spawnvpe(int, char *, char **, char **);


enum { _P_WAIT, _P_NOWAIT, _P_OVERLAY };

int execl(char *, char *,...);
int execle(char *, char *,...);
int execlp(char *, char *,...);
int execlpe(char *, char *,...);
int execv(char *, char **);
int execve(char *, char **, char **);
int execvp(char *, char **);
int execvpe(char *, char **, char **);


enum { WAIT_CHILD, WAIT_GRANDCHILD }

int cwait(int *,int,int);
int wait(int *);

uint _beginthread(void function(void *),uint,void *);

extern (Windows) alias uint (*stdfp)(void *);

uint _beginthreadex(void* security, uint stack_size,
	stdfp start_addr, void* arglist, uint initflag,
	uint* thrdaddr);

void _endthread();
void _endthreadex(uint);


int _wsystem(wchar *);
int _wspawnl(int, wchar *, wchar *, ...);
int _wspawnle(int, wchar *, wchar *, ...);
int _wspawnlp(int, wchar *, wchar *, ...);
int _wspawnlpe(int, wchar *, wchar *, ...);
int _wspawnv(int, wchar *, wchar **);
int _wspawnve(int, wchar *, wchar **, wchar **);
int _wspawnvp(int, wchar *, wchar **);
int _wspawnvpe(int, wchar *, wchar **, wchar **);

int _wexecl(wchar *, wchar *, ...);
int _wexecle(wchar *, wchar *, ...);
int _wexeclp(wchar *, wchar *, ...);
int _wexeclpe(wchar *, wchar *, ...);
int _wexecv(wchar *, wchar **);
int _wexecve(wchar *, wchar **, wchar **);
int _wexecvp(wchar *, wchar **);
int _wexecvpe(wchar *, wchar **, wchar **);
