extern(C) void __d_sys_exit(size_t arg1)
{
    version(linux)
    {
        version(X86_64)
        {
            asm
            {
                mov RAX, 60;
                mov RDI, arg1;
                syscall;
            }
        }
        else version(X86)
        {
            asm
            {
                mov EAX, 2;
                mov EDI, arg1;
                syscall;
            }
        }
    }
}

extern(C) void __assert(const(char)* exp, const(char)* file, uint line)
{
    version(linux)
        print("ASSERT ERROR\n");
    assert(0);
}

extern extern(C) int main();
private extern(C) void _start()
{
    __d_sys_exit(main());
}

void print(const char* c)
{
    print(c, c.strlen);
}

void print(const char* c, size_t len)
{
    version(linux)
    {
        version(X86_64)
        {
            asm
            {
                mov RDX, len;
                mov RSI, c;
                mov RAX, 1; // write
                mov RDI, RAX;
                syscall;
            }
        }
        else version(X86)
        {
            asm
            {
                mov EDX, len;
                mov ESI, c;
                mov EAX, 1; // write
                mov EDI, EAX;
                syscall;
            }
        }
    }
}

size_t strlen(const char* c)
{
    auto cptr = cast(char*) c;
    size_t i;
    while (*cptr != 0)
    {
        cptr++;
        i++;
    }
    return i;
}
