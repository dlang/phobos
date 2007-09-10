
/* Make D independent of all the various ways errno can be defined.
 */

#include <errno.h>

int getErrno()
{
    return errno;
}

int setErrno(int newno)
{
    errno = newno;
    return newno;
}
