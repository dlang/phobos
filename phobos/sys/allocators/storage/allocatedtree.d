/*
A list of allocations stored in a tree for fast lookup.

Prefer this over `AllocatedList` by default.

See_Also: AllocatedList

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.allocators.storage.allocatedtree;
public import phobos.sys.allocators.predefined : HouseKeepingAllocator;
import phobos.sys.allocators.api;
import phobos.sys.internal.attribute : hidden;
import phobos.sys.typecons : Ternary;

private
{
    alias AT = AllocatedTree!(RCAllocator, RCAllocator);
}

/**
A tree of all allocated memory, optionally supports a pool allocator that can be used to automatically deallocate all stored memory.

Warning: You must remove all memory (i.e. by deallocateAll) prior to destruction or you will get an error.

Warning: does not destroy on deallocation.
*/
struct AllocatedTree(InternalAllocator = HouseKeepingAllocator!(), PoolAllocator = void)
{
export:
    ///
    InternalAllocator internalAllocator;

    static if (!is(PoolAllocator == void))
    {
        ///
        PoolAllocator poolAllocator;
    }

    ///
    enum NeedsLocking = true;

    invariant
    {
        assert(anchor is null || !internalAllocator.isNull);
    }

    private
    {
        Node* anchor;
        ulong integritySearchKey;

        static struct Node
        {
            Node* left, right;
            void[] array;
            ulong seenIntegrity;

            TypeInfo typeInfo;

            bool matches(scope void* other) scope nothrow @nogc @hidden
            {
                return array.ptr <= other && (array.ptr + array.length) > other;
            }
        }
    }

@system @nogc nothrow:

    ///
     ~this()
    {
        static if (!is(PoolAllocator == void))
        {
            if (!poolAllocator.isNull)
                deallocateAll();
        }

        assert(anchor is null,
                "You didn't deallocate all memory before destruction of allocated list.");
    }

    ///
    bool isNull() const @safe
    {
        return internalAllocator.isNull;
    }

    ///
    this(return scope ref AllocatedTree other)
    {
        this.tupleof = other.tupleof;
        other = AllocatedTree.init;
    }

    static if (!is(PoolAllocator == void))
    {
        ///
        void deallocateAll()
        {
            deallocateAll(!poolAllocator.isNull ? &poolAllocator.deallocate : null);
        }
    }

    ///
    void deallocateAll(scope bool delegate(void[] array) nothrow @nogc deallocator)
    {
        void handle(Node* current)
        {
            if (current.left !is null)
                handle(current.left);
            if (current.right !is null)
                handle(current.right);

            if (deallocator !is null)
                deallocator(current.array);
            internalAllocator.dispose(current);
        }

        if (anchor !is null)
        {
            handle(anchor);
            anchor = null;
        }
    }

    ///
    bool empty()
    {
        return anchor is null;
    }

    ///
    Ternary owns(void[] array)
    {
        if (array is null)
            return Ternary.no;

        Node** nodeInParent = findPointerToNodeInParentGivenArray(array);

        if (*nodeInParent is null)
            return Ternary.no;

        return (*nodeInParent).matches(array.ptr) ? Ternary.yes : Ternary.no;
    }

    /// If memory is stored by us, will return the true region of memory associated with it.
    void[] getTrueRegionOfMemory(void[] array)
    {
        if (array is null)
            return null;

        Node** nodeInParent = findPointerToNodeInParentGivenArray(array);

        if (*nodeInParent is null || !(*nodeInParent).matches(array.ptr))
            return null;

        return (*nodeInParent).array;
    }

    /// If memory is stored by us, will return the true region of memory associated with it.
    void[] getTrueRegionOfMemory(void[] array, out TypeInfo ti)
    {
        if (array is null)
            return null;

        Node** nodeInParent = findPointerToNodeInParentGivenArray(array);

        if (*nodeInParent is null || !(*nodeInParent).matches(array.ptr))
            return null;

        ti = (*nodeInParent).typeInfo;
        return (*nodeInParent).array;
    }

    ///
    void store(void[] array, TypeInfo ti = null)
    {
        if (array is null)
            return;

        Node** parent = findPointerToNodeInParentGivenArray(array);
        Node* childOfParent = *parent;

        if (childOfParent !is null && childOfParent.matches(array.ptr))
        {
            const startPtrOfInput = array.ptr, lengthOfInput = array.length,
                endPtrOfInput = startPtrOfInput + lengthOfInput;
            const startPtrOfNode = childOfParent.array.ptr,
                lengthOfNode = childOfParent.array.length,
                endPtrOfNode = startPtrOfNode + lengthOfNode;
            const actualStartPtr = startPtrOfInput > startPtrOfNode ? startPtrOfNode : startPtrOfInput,
                actualEndPtr = endPtrOfInput > endPtrOfNode
                ? endPtrOfInput : endPtrOfNode, actualLength = actualEndPtr - actualStartPtr;

            if (startPtrOfInput !is startPtrOfNode)
            {
                removeNodeInParentAndRotate(parent);
                array = cast(void[]) actualStartPtr[0 .. actualLength];

                parent = findPointerToNodeInParentGivenArray(array);
                insertNodeIntoParentAndRotate(childOfParent, parent);
            }
            else if (lengthOfInput > lengthOfNode)
            {
                childOfParent.array = array;
            }
        }
        else
        {
            childOfParent = internalAllocator.make!Node;
            childOfParent.array = array;

            childOfParent.typeInfo = ti;
            insertNodeIntoParentAndRotate(childOfParent, parent);
        }
    }

    /// Caller is responsible for deallocation of memory
    void remove(void[] array)
    {
        if (array is null)
            return;

        Node** parent = findPointerToNodeInParentGivenArray(array);
        Node* current = *parent;

        if (current !is null && current.matches(array.ptr))
        {
            removeNodeInParentAndRotate(parent);
            internalAllocator.deallocate((cast(void*) current)[0 .. Node.sizeof]);
        }
    }

private @hidden:

    Node** findPointerToNodeInParentGivenArray(void[] array)
    {
        const startPtrOfInput = array.ptr;
        const endPtrOfInput = startPtrOfInput + array.length;
        Node** pointerToParent = &anchor;

        while (*pointerToParent !is null)
        {
            Node* parent = *pointerToParent;
            const startPtrOfParent = parent.array.ptr;
            const endPtrOfParent = startPtrOfParent + parent.array.length;

            Node** left = &parent.left, right = &parent.right;

            if (endPtrOfInput <= startPtrOfParent)
                pointerToParent = left;
            else if (endPtrOfParent <= startPtrOfInput)
                pointerToParent = right;
            else
                break;
        }

        return pointerToParent;
    }

    void insertNodeIntoParentAndRotate(Node* toInsert, Node** parent)
    {
        assert(toInsert !is null);

        const ptrOfInsert = toInsert.array.ptr;
        Node** ptrToNodeOnLeftOfParent = &toInsert.left, ptrToNodeOnRightOfParent = &toInsert.right;

        Node* orphenNode = *parent;
        *parent = toInsert;

        // handle orphens
        while (orphenNode !is null)
        {
            const ptrOfOrphen = orphenNode.array.ptr;

            if (ptrOfOrphen < ptrOfInsert)
            {
                *ptrToNodeOnLeftOfParent = orphenNode;
                ptrToNodeOnLeftOfParent = &orphenNode.right;

                orphenNode = orphenNode.right;
            }
            else
            {
                *ptrToNodeOnRightOfParent = orphenNode;
                ptrToNodeOnRightOfParent = &orphenNode.left;

                orphenNode = orphenNode.left;
            }
        }

        *ptrToNodeOnRightOfParent = null;
        *ptrToNodeOnRightOfParent = null;
    }

    void removeNodeInParentAndRotate(Node** parent)
    {
        Node* leftChild = (*parent).left, rightChild = (*parent).right;

        while (leftChild !is rightChild)
        {
            const startPtrOfLeft = leftChild !is null ? leftChild.array.ptr : null;
            const startPtrOfRight = rightChild !is null ? rightChild.array.ptr : null;

            if (startPtrOfLeft < startPtrOfRight)
            {
                *parent = rightChild;
                parent = &rightChild.left;

                rightChild = rightChild.left;
            }
            else
            {
                *parent = leftChild;
                parent = &leftChild.right;

                leftChild = leftChild.right;
            }
        }

        *parent = null;
    }

    void verifyIntegrity(int line = __LINE__)()
    {
        import core.stdc.stdlib : exit;

        const key = integritySearchKey++;
        int reason;

        int perNode(Node* parent)
        {
            if (parent.seenIntegrity < key)
                parent.seenIntegrity = key;
            else
                return 100;

            if (parent.array.length == 0 || parent.array.ptr is null)
                return 150;

            int got;

            if (parent.left !is null)
            {
                const startChildPtr = parent.left.array.ptr;
                const childLength = parent.left.array.length;
                const endChildPtr = startChildPtr + childLength;

                if (childLength == 0 || startChildPtr is null)
                    return 200;
                else if (endChildPtr >= parent.array.ptr)
                    return 250;

                got = perNode(parent.left);
                if (got)
                    return got;
            }

            if (parent.right !is null)
            {
                const startChildPtr = parent.right.array.ptr;
                const childLength = parent.right.array.length;
                const endParentPtr = parent.array.ptr + parent.array.length;

                if (childLength == 0 || startChildPtr is null)
                    return 300;
                else if (startChildPtr < endParentPtr)
                    return 350;

                got = perNode(parent.right);
                if (got)
                    return got;
            }

            return 0;
        }

        if (this.anchor !is null)
            reason = perNode(this.anchor);

        if (reason != 0)
            debug exit(reason);
    }
}

///
unittest
{
    alias AT = AllocatedTree!();

    AT at;
    assert(!at.isNull);
    assert(at.empty);

    at = AT();
    assert(!at.isNull);
    assert(at.empty);

    void[] someArray = new void[1024];
    at.store(someArray);
    assert(!at.empty);
    assert(at.owns(null) == Ternary.no);
    assert(at.owns(someArray) == Ternary.yes);
    assert(at.owns(someArray[10 .. 20]) == Ternary.yes);
    assert(at.getTrueRegionOfMemory(someArray[10 .. 20]) is someArray);

    void[] someArray2 = new void[512];
    at.store(someArray2);
    assert(!at.empty);
    assert(at.owns(null) == Ternary.no);
    assert(at.owns(someArray2) == Ternary.yes);
    assert(at.owns(someArray2[10 .. 20]) == Ternary.yes);
    assert(at.getTrueRegionOfMemory(someArray2[10 .. 20]) is someArray2);

    void[] someArray3 = new void[1024];
    at.store(someArray3);
    assert(!at.empty);
    assert(at.owns(null) == Ternary.no);
    assert(at.owns(someArray3) == Ternary.yes);
    assert(at.owns(someArray3[10 .. 20]) == Ternary.yes);
    assert(at.getTrueRegionOfMemory(someArray3[10 .. 20]) is someArray3);

    at.remove(someArray);
    assert(at.owns(someArray) == Ternary.no);
    assert(at.owns(someArray2) == Ternary.yes);
    assert(at.owns(someArray3) == Ternary.yes);
    at.remove(someArray2);
    assert(at.owns(someArray) == Ternary.no);
    assert(at.owns(someArray2) == Ternary.no);
    assert(at.owns(someArray3) == Ternary.yes);
    at.remove(someArray3);
    assert(at.owns(someArray) == Ternary.no);
    assert(at.owns(someArray2) == Ternary.no);
    assert(at.owns(someArray3) == Ternary.no);
    assert(at.empty);

    at.store(someArray);
    assert(!at.empty);

    int got;
    at.deallocateAll((array) { got += array == someArray ? 1 : 0; return true; });
    assert(got == 1);
}
