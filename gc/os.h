
// OS specific routines

void *os_mem_map(unsigned nbytes);
int os_mem_commit(void *base, unsigned offset, unsigned nbytes);
int os_mem_decommit(void *base, unsigned offset, unsigned nbytes);
int os_mem_unmap(void *base, unsigned nbytes);
void os_query_staticdataseg(void **base, unsigned *nbytes);


// Threading

#if defined linux
#include <pthread.h>
#else
typedef long pthread_t;
pthread_t pthread_self();
#endif
