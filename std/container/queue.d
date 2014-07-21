module std.container.queue;

/++ 
 + Implements a queue container, which is a
 + FIFO (First in, first out) structure. This
 + container is a simple abstraction over a T[].
+/
@safe public struct Queue(T)
{
private:
    bool pIsSizable;
    int pCapacity;

    T[] pContents;

public:
    /++ Creates an empty queue with the specified capacity.
     + 
     + Params:
     +      capacity =   The number of items T that the queue can store.
     +      sizable  =   Whether the queue can change capacity.
    +/
    this(int capacity, bool sizable = true) nothrow
    {
        this.pIsSizable = sizable;
        this.pCapacity = capacity;
    }
    @disable this();

    ~this() {
        this.pContents.destroy;
    }

    /++
     + Adds an item to the end of the queue.
     + 
     + Params:
     +      item =  The item to add to the queue.
     + 
     + Returns: True if the item was added.
     +          False if queue capacity has been reached.
    +/
    bool enqueue(in T item) {
        // Check whether queue has free space.
        if (this.capacity > this.length) {
            // Add the item to the end of the queue
            // if there is free space.
            this.pContents ~= item;
            // Indicate successful enqueuing.
            return true;
        }
        else {
            // If there isn't any free space, check
            // to see whether we are permitted to 
            // resize the queue.
            if (this.sizable) {
                // If we are able to resize the queue,
                // append the item to the end of it.
                this.pContents ~= item;
                // Increase the capacity of the queue.
                ++this.pCapacity;
                // Indicate successful enqueuing.
                return true;
            }
            else {
                // We cannot resize the queue, and the
                // queue is at capacity. Indicate failure.
                return false;
            }
        }
    }
    /++
     + Adds an item to the end of queue and returns the
     + queue the item was added to.
     + 
     + Params:
     +      item    =   The item to add to the queue.
     +      success =   Whether the enqueuing was successful.
     + 
     + Returns: The queue the item was added to.
    +/
    ref Queue!T penqueue(in T item, out bool success) {
        success = this.enqueue(item);

        return this;
    }
    /++ Retrieves the item at the front of the queue and
     + removes it from the queue.
     + 
     + Params:
     +      item =  The variable to deposit the item at the
     +              start of the queue in to.
     + 
     + Returns: True if the item was retrieved.
     +          False if there are no items to retrieve.
    +/
    bool dequeue(out T item) {
        // Check to make sure that there are items
        // to retrieve from the queue.
        if (this.length == 0) {
            // If there aren't items, we indicate
            // as much.
            return false;
        }
        else {
            // We know there are items to retrieve,
            // which means our array has at least a
            // single element in it. The item at index
            // zero is at the front of the queue.
            auto val = this.pContents[0];

            // Slice the array to get rid of the first
            // index.
            this.pContents = pContents[1..$];

            // Set the item to the retrieved value.
            item = val;
            // Indicate successful dequeuing.
            return true;
        }
    }
    /++
     + Retrieves the item at the front of the queue and
     + removes it from the queue. Returns the queue the
     + item was removed from.
     + 
     + Params:
     +      item    =   The variable to deposit the item at the
     +                  start of the queue in to.
     +      success =   Whether the dequeuing was successful.
     + 
     + Returns: The queue the item was removed from.
    +/
    ref Queue!T pdequeue(out T item, out bool success) {
        success = this.dequeue(item);

        return this;
    }
    /++ Removes all items from the queue. +/
    void clear() {
        this.pContents.length = 0;
    }

    /++ Whether this queue can be resized. +/
    @property bool sizable() pure nothrow {
        return this.pIsSizable;
    }
    /++ The current capacity of the queue. +/
    @property int capacity() pure nothrow {
        return this.pCapacity;
    }
    /++ The current number of items in the queue. +/
    @property int length() pure nothrow {
        return this.pContents.length;
    }
}


@safe pure nothrow unittest {
    auto q = Queue!int(4);
    bool s = q.enqueue(42);

    assert(s);
    assert(q.capacity == 4);
    assert(q.length == 1);
}

@safe pure nothrow unittest {
    auto q = Queue!int(1, false);
    bool e = q.enqueue(100);

    assert(e);
    assert(q.capacity == 1);
    assert(q.length == 1);
    assert(!q.sizable);

    bool f = q.enqueue(200);
    assert(!f);
    assert(q.capacity == 1);
    assert(q.length == 1);
}

@safe pure nothrow unittest {
    auto q = Queue!int(1);
    q.enqueue(42);

    assert(q.length == q.capacity);

    int i;
    bool s = q.dequeue(i);

    assert(s);
    assert(i == 42);
    assert(q.length == 0);
    assert(q.capacity == 1);
}

@safe pure nothrow unittest {
    auto q = Queue!int(2);

    q.enqueue(4);
    q.enqueue(2);
    assert(q.length == 2);

    q.clear();
    assert(q.length == 0);
    assert(q.capacity == 2);
}

@safe pure nothrow unittest {
    auto q = Queue!int(2);

    bool s1, s2;
    q.penqueue(1, s1).penqueue(2, s2);

    assert(s1 && s2);
    assert(q.length == 2);

    bool r1, r2;
    int i1, i2;
    q.pdequeue(i1, r1).pdequeue(i2, r2);

    assert(r1 && r2);
    assert(i1 == 1);
    assert(i2 == 2);
    assert(q.length == 0);
}

@safe pure nothrow unittest {
    auto q = Queue!int(0);

    q.enqueue(100);

    assert(q.capacity == 1);
}