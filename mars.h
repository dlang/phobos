
#if __cplusplus
extern "C" {
#endif

struct ClassInfo;
struct Vtbl;

typedef struct Vtbl
{
    unsigned len;
    void **vptr;
} Vtbl;

typedef struct Interface
{
    struct ClassInfo *classinfo;
    struct Vtbl vtbl;
} Interface;

typedef struct Object
{
    void **vptr;
    unsigned monitor;
} Object;

typedef struct ClassInfo
{
    Object object;

    unsigned initlen;
    void *init;

    unsigned namelen;
    char *name;

    Vtbl vtbl;

    unsigned interfacelen;
    Interface *interfaces;

    struct ClassInfo *baseClass;

    void *destructor;
    void *invariant;
} ClassInfo;

typedef struct Exception
{
    Object object;

    unsigned msglen;
    char *msg;
} Exception;

void _d_monitorenter(Object *h);
void _d_monitorexit(Object *h);
void _d_monitorrelease(Object *h);

int _d_isbaseof(ClassInfo *b, ClassInfo *c);
Object *_d_dynamic_cast(Object *o, ClassInfo *ci);

Object * __ddecl __d_newclass(ClassInfo *ci);
void __ddecl _d_delclass(Object **p);

void _d_OutOfMemory();

#if __cplusplus
}
#endif

