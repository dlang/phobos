
/* Written by Walter Bright, Sean Kelly, and many others.
 * www.digitalmars.com
 * Placed into public domain.
 */

module std.c.osx.osx;

public import std.c.linux.linux : pthread_t;

extern (C):

alias int kern_return_t;

enum : kern_return_t
{
    KERN_SUCCESS                = 0,
    KERN_INVALID_ADDRESS        = 1,
    KERN_PROTECTION_FAILURE     = 2,
    KERN_NO_SPACE               = 3,
    KERN_INVALID_ARGUMENT       = 4,
    KERN_FAILURE                = 5,
    KERN_RESOURCE_SHORTAGE      = 6,
    KERN_NOT_RECEIVER           = 7,
    KERN_NO_ACCESS              = 8,
    KERN_MEMORY_FAILURE         = 9,
    KERN_MEMORY_ERROR           = 10,
    KERN_ALREADY_IN_SET         = 11,
    KERN_NOT_IN_SET             = 12,
    KERN_NAME_EXISTS            = 13,
    KERN_ABORTED                = 14,
    KERN_INVALID_NAME           = 15,
    KERN_INVALID_TASK           = 16,
    KERN_INVALID_RIGHT          = 17,
    KERN_INVALID_VALUE          = 18,
    KERN_UREFS_OVERFLOW         = 19,
    KERN_INVALID_CAPABILITY     = 20,
    KERN_RIGHT_EXISTS           = 21,
    KERN_INVALID_HOST           = 22,
    KERN_MEMORY_PRESENT         = 23,
    KERN_MEMORY_DATA_MOVED      = 24,
    KERN_MEMORY_RESTART_COPY    = 25,
    KERN_INVALID_PROCESSOR_SET  = 26,
    KERN_POLICY_LIMIT           = 27,
    KERN_INVALID_POLICY         = 28,
    KERN_INVALID_OBJECT         = 29,
    KERN_ALREADY_WAITING        = 30,
    KERN_DEFAULT_SET            = 31,
    KERN_EXCEPTION_PROTECTED    = 32,
    KERN_INVALID_LEDGER         = 33,
    KERN_INVALID_MEMORY_CONTROL = 34,
    KERN_INVALID_SECURITY       = 35,
    KERN_NOT_DEPRESSED          = 36,
    KERN_TERMINATED             = 37,
    KERN_LOCK_SET_DESTROYED     = 38,
    KERN_LOCK_UNSTABLE          = 39,
    KERN_LOCK_OWNED             = 40,
    KERN_LOCK_OWNED_SELF        = 41,
    KERN_SEMAPHORE_DESTROYED    = 42,
    KERN_RPC_SERVER_TERMINATED  = 43,
    KERN_RPC_TERMINATE_ORPHAN   = 44,
    KERN_RPC_CONTINUE_ORPHAN    = 45,
    KERN_NOT_SUPPORTED          = 46,
    KERN_NODE_DOWN              = 47,
    KERN_OPERATION_TIMED_OUT    = 49,
    KERN_RETURN_MAX             = 0x100,
}

version( X86 )
    version = i386;
version( X86_64 )
    version = i386;
version( i386 )
{
    alias uint        natural_t;
    alias natural_t   mach_port_t;
    alias mach_port_t thread_act_t;
    alias void        thread_state_t;
    alias int         thread_state_flavor_t;
    alias natural_t   mach_msg_type_number_t;

    enum
    {
        x86_THREAD_STATE32      = 1,
        x86_FLOAT_STATE32       = 2,
        x86_EXCEPTION_STATE32   = 3,
        x86_THREAD_STATE64      = 4,
        x86_FLOAT_STATE64       = 5,
        x86_EXCEPTION_STATE64   = 6,
        x86_THREAD_STATE        = 7,
        x86_FLOAT_STATE         = 8,
        x86_EXCEPTION_STATE     = 9,
        x86_DEBUG_STATE32       = 10,
        x86_DEBUG_STATE64       = 11,
        x86_DEBUG_STATE         = 12,
        THREAD_STATE_NONE       = 13,
    }

    struct x86_thread_state32_t
    {
        uint    eax;
        uint    ebx;
        uint    ecx;
        uint    edx;
        uint    edi;
        uint    esi;
        uint    ebp;
        uint    esp;
        uint    ss;
        uint    eflags;
        uint    eip;
        uint    cs;
        uint    ds;
        uint    es;
        uint    fs;
        uint    gs;
    }

    struct x86_thread_state64_t
    {
        ulong   rax;
        ulong   rbx;
        ulong   rcx;
        ulong   rdx;
        ulong   rdi;
        ulong   rsi;
        ulong   rbp;
        ulong   rsp;
        ulong   r8;
        ulong   r9;
        ulong   r10;
        ulong   r11;
        ulong   r12;
        ulong   r13;
        ulong   r14;
        ulong   r15;
        ulong   rip;
        ulong   rflags;
        ulong   cs;
        ulong   fs;
        ulong   gs;
    }

    struct x86_state_hdr_t
    {
        int     flavor;
        int     count;
    }

    struct x86_thread_state_t
    {
        x86_state_hdr_t             tsh;
        union _uts
        {
            x86_thread_state32_t    ts32;
            x86_thread_state64_t    ts64;
        }
        _uts                        uts;
    }

    enum : mach_msg_type_number_t
    {
        x86_THREAD_STATE32_COUNT = cast(mach_msg_type_number_t)( x86_thread_state32_t.sizeof / int.sizeof ),
        x86_THREAD_STATE64_COUNT = cast(mach_msg_type_number_t)( x86_thread_state64_t.sizeof / int.sizeof ),
        x86_THREAD_STATE_COUNT   = cast(mach_msg_type_number_t)( x86_thread_state_t.sizeof / int.sizeof ),
    }

    alias x86_THREAD_STATE          MACHINE_THREAD_STATE;
    alias x86_THREAD_STATE_COUNT    MACHINE_THREAD_STATE_COUNT;

    mach_port_t   mach_thread_self();
    mach_port_t   pthread_mach_thread_np(pthread_t);
    kern_return_t thread_suspend(thread_act_t);
    kern_return_t thread_resume(thread_act_t);
    kern_return_t thread_get_state(thread_act_t, thread_state_flavor_t, thread_state_t*, mach_msg_type_number_t*);
}
