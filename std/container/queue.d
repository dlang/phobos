module std.container.queue;

import std.traits, std.exception;

/++ Implements a queue structure, where the
 + first item added to the queue is the first
 + item to be dequeued (FIFO).
+/
public struct Queue(T) 
{
private:
    int pLength;
    T[] pItems;

    // The index of the front of the queue
    int pCurrIndex;
    // The next free index in the queue
    int pNextIndex;

public:
    /++ Creates a new queue with the specified capacity.
     + 
     + Params:
     +         capacity =    The number of items the queue is able to hold.
    +/
    this(int capacity)
    {
        // Check to ensure that capacity is valid.
        if (capacity < 0) 
        {
            throw new Exception("Queues cannot have negative capacity.");
        }
        else 
        {
            pLength = 0;
            pItems.length = capacity;
        }
    }
    @disable this();
    ~this() 
    {
        static if (hasElaborateDestructor!T) 
        {
            foreach (ref i; pItems) 
            {
                .destroy(i);
            }
        }

        .destroy(pItems);
    }

    /++ Adds an item to the end of the queue.
     + 
     + Params:
     +         item =    The item to add to the queue.
    +/
    void enqueue(in T item)
    {
        // Ensure that we have space to add new items to
        // the queue.
        if (length == capacity) 
        {
            throw new Exception("Queue is at capacity.");
        }
        else {
            // Set the next free index to the value of the item.
            pItems[pNextIndex] = item;
            // Increment the length of the queue to accurately
            // reflect its new length.
            ++pLength;
            // If the queue can hold only a single item, then
            // we will never need to change the value of the
            // field containing the next free index.
            if (capacity > 1) 
            {
                // Adjust the next free index appropriately. Allows
                // the index to wrap around, which makes it easier
                // for us to start reusing the array indices of
                // dequeued values.
                ++pNextIndex %= capacity;
            }
        }
    }
    /++ Retrieves the item at the front of the queue.
     + 
     + Returns: The item at the front of the queue.
    +/
    T dequeue()
    {
        // Check to make sure that there are actually items in
        // the queue to be read.
        if (empty) 
        {
            // If there aren't, raise an exception.
            throw new Exception("Queue is empty.");
        }
        else 
        {
            // Retrieve the item at the start of the
            // queue for returning.
            T rval = pItems[pCurrIndex];
            // Decrement the length of the queue to
            // reflect that this item has been
            // removed from it.
            --pLength;
            // If the capacity of the queue is one,
            // then the current index will always
            // be the same, and we never need to
            // change it.
            if (capacity > 1) 
            {
                // Adjust the current index to point to
                // the next item in the queue.
                ++pCurrIndex %= capacity;
            }
            // Return the retrieved values.
            return rval;
        }
    }
    /++ Adds an item to the end of the queue and
    + returns the queue the item was added to.
    +
    + Returns: The queue the item was added to.
    +/
    ref Queue!T penqueue(in T item)
    {
        enqueue(item);
        return this;
    }
    /++ Retrieves the item at the end of the
    + queue and returns the queue it was removed
    + from.
    +
    + Returns: The queue the item was removed from.
    +/
    ref Queue!T pdequeue(out T item)
    {
        item = dequeue();
        return this;
    }


    bool opEquals(const Queue!T q) nothrow 
    {
        // Make sure the queues are of the same
        // length and capacity.                
        if (q.length == this.length && q.capacity == this.capacity)
        {
            // If they are the same length/capacity,
            // we can move on to checking their values.
            // We need to copy their current indices
            // so we can iterate through their items.
            int tIn = pCurrIndex;
            int cIn = q.pCurrIndex;

            bool valEquals = true;
            // To compare their values, we need to iterate
            // over them. If the value of valEquals becomes
            // false at any time, we know that the queues
            // are inequal, and this means we don't need to
            // keep iterating over them.
            for (int i = 0; i < length && valEquals; i++) 
            {
                // It is likely that the positions within their
                // arrays will be different, so we need to maintain
                // two separate counters for each item. We also need
                // to access the index mod the length as this allows
                // us to wrap back around to the items at lower indices
                // in the array but which may be nearer the end of the
                // queue.
                valEquals = 
                    this.pItems[tIn++ % length] == q.pItems[cIn++ % length];
            }
            // Regardless of outcome, valEquals will contain the correct
            // value indicating equality, so we can just return it.
            return valEquals;
        }
        else 
        {
            // If the queues are not of the same
            // length/capacity, there's no point
            // in checking values as we already
            // know that they are not equal.
            return false;
        }
    }

    /++ Empties the queue. +/
    void clear() 
    {
        this.pLength = 0;
        this.pCurrIndex = 0;
        this.pNextIndex = 0;
    }

    /++ The number of items the queue is able to store. +/
    @property const int capacity() nothrow 
    {
        return pItems.length;
    }
    /++ The number of items the queue currently holds. +/
    @property const int length() nothrow 
    {
        return pLength;
    }
    /++ Whether the queue contains any items. +/
    @property const bool empty() nothrow 
    {
        return length == 0;
    }
}

@safe pure unittest 
{
    auto q = Queue!int(5);

    assert(q.length == 0, "std.container.Queue: Length set incorrectly.");
    assert(q.capacity == 5, "std.container.Queue: Capacity set incorrectly.");
}

@safe pure unittest 
{
    auto q = Queue!int(1);

    q.enqueue(100);
    assert(q.length == 1, "std.container.Queue: Length adjusted incorrectly.");
}

@safe pure unittest 
{
    auto q = Queue!int(1);

    q.enqueue(100);

    assertThrown!Exception(q.enqueue(101));
}

@safe pure unittest 
{
    auto q = Queue!int(1);

    assertThrown!Exception(q.dequeue());
}

@safe pure unittest 
{
    static immutable string inCurr = "std.container.Queue: Current index set incorrectly.";
    static immutable string inNext = "std.container.Queue: Next index set incorrectly.";
    static immutable string nFront = "std.container.Queue: Front of queue not retrieved.";
    static immutable string inLeng =  "std.container.Queue: Length adjusted incorrectly.";

    auto q = Queue!int(2);

    q.enqueue(100);
    assert(q.pCurrIndex == 0, inCurr);
    assert(q.pNextIndex == 1, inNext);

    q.enqueue(101);
    assert(q.pCurrIndex == 0, inCurr);
    assert(q.pNextIndex == 0, inNext);

    auto dq = q.dequeue();
    assert(q.pCurrIndex == 1, inCurr);
    assert(q.pNextIndex == 0, inNext);

    assert(dq == 100, nFront);
    assert(q.length == 1, inLeng);

    q.enqueue(102);
    assert(q.pCurrIndex == 1, inCurr);
    assert(q.pNextIndex == 1, inNext);

    auto dq2 = q.dequeue();
    assert(q.pCurrIndex == 0, inCurr);
    assert(q.pNextIndex == 1, inNext);

    auto dq3 = q.dequeue();
    assert(q.pCurrIndex == 1, inCurr);
    assert(q.pNextIndex == 1, inNext);

    assert(dq2 == 101, nFront);
    assert(dq3 == 102, nFront);
}

@safe pure unittest 
{
    auto q0 = Queue!int(2);
    q0.enqueue(50);

    auto q1 = Queue!int(2);
    q1.enqueue(50);

    assert(q0 == q1, "std.container.Queue: Equality determined incorrectly.");
}

@safe pure unittest 
{
    auto q0 = Queue!int(1);
    auto q1 = Queue!int(2);

    assert(q0 != q1, "std.container.Queue: Inequality determined incorrectly.");
}

@safe pure unittest 
{
    auto q0 = Queue!int(1);
    q0.enqueue(100);

    auto q1 = Queue!int(1);
    q1.enqueue(200);

    assert(q0 != q1, "std.container.Queue: Inequality determined incorrectly.");
}
