
module std.c.stdlib;

extern (C):

enum
{
    _MAX_PATH   = 260,
    _MAX_DRIVE  = 3,
    _MAX_DIR    = 256,
    _MAX_FNAME  = 256,
    _MAX_EXT    = 256,
}

struct div_t { int  quot,rem; }
struct ldiv_t { int quot,rem; }
struct lldiv_t { long quot,rem; }

    div_t div(int,int);
    ldiv_t ldiv(int,int);
    lldiv_t lldiv(long, long);

    const int EXIT_SUCCESS = 0;
    const int EXIT_FAILURE = 1;

    int    atexit(void (*)());
    void   exit(int);
    void   _exit(int);

    void *alloca(uint);

    void *calloc(uint, uint);
    void *malloc(uint);
    void *realloc(void *, uint);
    void free(void *);

    void *bsearch(void *,void *,size_t,size_t,
       int function(void *,void *));
    void qsort(void *base, uint nelems, uint elemsize,
	int (*compare)(void *elem1, void *elem2));

    char* getenv(char*);

    int    rand();
    void   srand(uint);
    int    random(int num);
    void   randomize();

    int getErrno();
    int setErrno(int);

double atof(char *);
int    atoi(char *);
int    atol(char *);
double strtod(char *,char **);
real   strtold(char *,char **);
long   strtol(char *,char **,int);
uint   strtoul(char *,char **,int);
long   atoll(char *);
long   strtoll(char *,char **,int);
ulong  strtoull(char *,char **,int);

char* itoa(int, char*, int);
char* ultoa(uint, char*, int);

