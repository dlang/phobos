/* 
 * Author  : Adil Baig (github.com/adilbaig)
 * Date    : 2012
 * License : Public Domain 
 *
 * Interface to the Linux epoll interface (http://man7.org/linux/man-pages/man7/epoll.7.html)
 * Available since Linux 2.6  
 */

enum
{
    EPOLL_CLOEXEC  = 0x80000,
    EPOLL_NONBLOCK = 0x800
};

enum 
{
    EPOLLIN 	= 0x001,
    EPOLLPRI 	= 0x002,
    EPOLLOUT 	= 0x004,
    EPOLLRDNORM = 0x040,
    EPOLLRDBAND = 0x080,
    EPOLLWRNORM = 0x100,
    EPOLLWRBAND = 0x200,
    EPOLLMSG 	= 0x400,
    EPOLLERR 	= 0x008,
    EPOLLHUP 	= 0x010,
    EPOLLRDHUP 	= 0x2000, // since Linux 2.6.17
    EPOLLONESHOT = 1u << 30,
    EPOLLET 	= 1u << 31
};

/* Valid opcodes ( "op" parameter ) to issue to epoll_ctl().  */
enum
{
    EPOLL_CTL_ADD = 1, // Add a file descriptor to the interface.
    EPOLL_CTL_DEL = 2, // Remove a file descriptor from the interface.
    EPOLL_CTL_MOD = 3, // Change file descriptor epoll_event structure.
};

struct epoll_event 
{ 
     uint events;
     epoll_data_t data;
};

private union epoll_data_t 
{
    void *ptr;
    int fd;
    uint u32;
    ulong u64;
};
 

extern (C) :

/* Creates an epoll instance. Returns an fd for the new instance.
   The "size" parameter is a hint specifying the number of file
   descriptors to be associated with the new instance. The fd
   returned by epoll_create() should be closed with close().  
*/
int epoll_create (int size);

/* Same as epoll_create but with an FLAGS parameter.  The unused SIZE
   parameter has been dropped.  */
int epoll_create1 (int flags);


/* Manipulate an epoll instance "epfd". Returns 0 in case of success,
   -1 in case of error ( the "errno" variable will contain the
   specific error code ) The "op" parameter is one of the EPOLL_CTL_*
   enums defined above. The "fd" parameter is the target of the
   operation. The "event" parameter describes which events the caller
   is interested in and any associated user data.  
*/
int epoll_ctl (int epfd, int op, int fd, const epoll_event *event);


/* Wait for events on an epoll instance "epfd". Returns the number of
   triggered events returned in "events" buffer. Or -1 in case of
   error with the "errno" variable set to the specific error code. The
   "events" parameter is a buffer that will contain triggered
   events. The "maxevents" is the maximum number of events to be
   returned ( usually size of "events" ). The "timeout" parameter
   specifies the maximum wait time in milliseconds (-1 == infinite).
*/
int epoll_wait (int epfd, const epoll_event *events, int maxevents, int timeout);