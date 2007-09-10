
module std.c.stdlib;

extern (C):

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

