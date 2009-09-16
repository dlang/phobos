// Written in the D programming language.

/**
Implements processor dependent parts of the atomics library.

Macros:
    WIKI = Phobos/Atomics
    
Copyright: Copyright Bartosz Milewski 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Bartosz Milewski

         Copyright Bartosz Milewski 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/

version (D_InlineAsm_X86)
{

/**
Compare And Swap. The engine behind lock-free algorithms.

In one atomic operation, it tests the contents of $(D addr) and, if it's eqaul to $(D old), overwrites it with $(D new_val) and returns $(D true). Otherwise returns $(D false). 
*/
bool CAS(uint * addr, uint old, uint new_val)
{
asm {
    mov EDX, addr;
    mov ECX, new_val;
    mov EAX, old;
    lock;
    cmpxchg [EDX], ECX;
    setz DL;
    movzx EAX, DL;
  }
}

/** 
Stops the compiler from performing code motion across the barrier.
It's not a memory fence.
*/
void compiler_fence()
{
asm {
  }
}

// The x86 implements processor-order memory model, so fences are not strictly necessary.
// 

/** Memory read fence (includes compiler fence)
*/
void read_fence()
{
asm {
  }
}

/** Memory write fence (includes compiler fence)
*/
void write_fence()
{
asm {
  }
}

} // D_InlineAsm_X86

unittest
{
    uint x = 1;
        bool success = CAS(&x, 1, 2);
        assert(success);
        assert(x == 2);
        
        success = CAS(&x, 1, 3);
        assert(!success);
        assert(x == 2);
}
