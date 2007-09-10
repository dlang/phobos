
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

    void qsort(void *base, uint nelems, uint elemsize,
	int (*compare)(void *elem1, void *elem2));

    char* getenv(char*);

    int    rand();
    void   srand(uint);
    int    random(int num);
    void   randomize();

