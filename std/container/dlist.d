module std.container.dlist;

import std.exception, std.range, std.traits;
public import std.container.util;

/**
Implements a doubly-linked list.

$(D DList) uses neither reference nor value semantics. They can be seen as
several different handles into an external chain of nodes. Several different
$(D DList)s can all reference different points in a same chain.

$(D DList.Range) is, for all intents and purposes, a DList with range
semantics. The $(D DList.Range) has a view directly into the chain itself.
It is not tied to its parent $(D DList), and may be used to operate on
other lists (that point to the same chain).

The ONLY operation that can invalidate a $(D DList) or $(D DList.Range), but
which will invalidate BOTH, is the $(D remove) operation, if the cut Range
overlaps with the boundaries of another DList or DList.Range.

Example:
----
auto a = DList!int([3, 4]); //Create a new chain
auto b = a; //Point to the same chain
// (3 - 4)
assert(a[].equal([3, 4]));
assert(b[].equal([3, 4]));

b.stableInsertFront(1); //insert before of b
b.stableInsertBack(5); //insert after of b
// (2 - (3 - 4) - 5)
assert(a[].equal([3, 4])); //a is not changed
assert(b[].equal([1, 3, 4, 5])); // but b is changed

a.stableInsertFront(2); //insert in front of a, this will insert "inside" the chain
// (1 - (2 - 3 - 4) - 5)
assert(a[].equal([2, 3, 4])); //a is modified
assert(b[].equal([1, 2, 3, 4, 5])); //and so is b;

a.remove(a[]); //remove all the elements of a: This will cut them from the chain;
// (1 - 5)
assert(a[].empty); //a is empty
assert(b[].equal([1, 5])); //b has lost some of its elements;

a.insert(2); //insert in a. This will create a new chain
// (2)
// (1 - 5)
assert(a[].equal([2])); //a is a new chain
assert(b[].equal([1, 5])); //b is unchanged;
----
 */
struct DList(T)
{
    private struct Node
    {
        T _payload;
        Node * _prev;
        Node * _next;
        this(T a, Node* p, Node* n)
        {
            _payload = a;
            _prev = p; _next = n;
            if (p) p._next = &this;
            if (n) n._prev = &this;
        }
    }
    private Node * _first;
    private Node * _last;

/**
Constructor taking a number of nodes
     */
    this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
    {
        insertBack(values);
    }

/**
Constructor taking an input range
     */
    this(Stuff)(Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        insertBack(stuff);
    }

/**
Comparison for equality.

Complexity: $(BIGOH min(n, n1)) where $(D n1) is the number of
elements in $(D rhs).
     */
    bool opEquals()(ref const DList rhs) const
    if (is(typeof(front == front)))
    {
        if(_first == rhs._first) return _last == rhs._last;
        if(_last == rhs._last) return false;

        const(Node)* nthis = _first, nrhs = rhs._first;
        while(true)
        {
            if (!nthis) return !nrhs;
            if (!nrhs || nthis._payload != nrhs._payload) return false;
            nthis = nthis._next;
            nrhs = nrhs._next;
        }
    }

    /**
    Defines the container's primary range, which embodies a bidirectional range.
     */
    struct Range
    {
        private Node * _first;
        private Node * _last;
        private this(Node* first, Node* last)
        {
            assert(!!_first == !!_last, "Dlist.Rangethis: Invalid arguments");
            _first = first; _last = last;
        }
        private this(Node* n) { _first = _last = n; }

        /// Input range primitives.
        @property const nothrow
        bool empty()
        {
            assert(!!_first == !!_last, "DList.Range: Invalidated state");
            return !_first;
        }

        /// ditto
        @property ref T front()
        {
            assert(!empty, "DList.Range.front: Range is empty");
            return _first._payload;
        }

        /// ditto
        void popFront()
        {
            assert(!empty, "DList.Range.popFront: Range is empty");
            if (_first is _last)
            {
                _first = _last = null;
            }
            else
            {
                assert(_first is _first._next._prev, "DList.Range: Invalidated state");
                _first = _first._next;
            }
        }

        /// Forward range primitive.
        @property Range save() { return this; }

        /// Bidirectional range primitives.
        @property ref T back()
        {
            assert(!empty, "DList.Range.back: Range is empty");
            return _last._payload;
        }

        /// ditto
        void popBack()
        {
            assert(!empty, "DList.Range.popBack: Range is empty");
            if (_first is _last)
            {
                _first = _last = null;
            }
            else
            {
                assert(_last is _last._prev._next, "DList.Range: Invalidated state");
                _last = _last._prev;
            }
        }
    }

    unittest
    {
        static assert(isBidirectionalRange!Range);
    }

/**
Property returning $(D true) if and only if the container has no
elements.

Complexity: $(BIGOH 1)
     */
    @property const nothrow
    bool empty()
    {
        assert(!!_first == !!_last, "DList: Internal error, inconsistant list");
        return _first is null;
    }

/**
Removes all contents from the $(D DList).

Postcondition: $(D empty)

Complexity: $(BIGOH 1)
     */
    void clear()
    {
        //remove actual elements.
        remove(this[]);
    }

/**
Duplicates the container. The elements themselves are not transitively
duplicated.

Complexity: $(BIGOH n).
     */
    @property DList dup()
    {
        return DList(this[]);
    }

/**
Returns a range that iterates over all elements of the container, in
forward order.

Complexity: $(BIGOH 1)
     */
    Range opSlice()
    {
        return Range(_first, _last);
    }

/**
Forward to $(D opSlice().front).

Complexity: $(BIGOH 1)
     */
    @property ref inout(T) front() inout
    {
        assert(!empty, "DList.front: List is empty");
        return _first._payload;
    }

/**
Forward to $(D opSlice().back).

Complexity: $(BIGOH 1)
     */
    @property ref inout(T) back() inout
    {
        assert(!empty, "DList.back: List is empty");
        return _last._payload;
    }

/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/
/+                        BEGIN CONCAT FUNCTIONS HERE                         +/
/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/

/**
Returns a new $(D DList) that's the concatenation of $(D this) and its
argument $(D rhs).
     */
    DList opBinary(string op, Stuff)(Stuff rhs)
    if (op == "~" && is(typeof(insertBack(rhs))))
    {
        auto ret = this.dup;
        ret.insertBack(rhs);
        return ret;
    }
    /// ditto
    DList opBinary(string op)(DList rhs)
    if (op == "~")
    {
        return ret ~ rhs[];
    }

/**
Returns a new $(D DList) that's the concatenation of the argument $(D lhs)
and $(D this).
     */
    DList opBinaryRight(string op, Stuff)(Stuff lhs)
    if (op == "~" && is(typeof(insertFront(lhs))))
    {
        auto ret = this.dup;
        ret.insertFront(lhs);
        return ret;
    }

/**
Appends the contents of the argument $(D rhs) into $(D this).
     */
    DList opOpAssign(string op, Stuff)(Stuff rhs)
    if (op == "~" && is(typeof(insertBack(rhs))))
    {
        insertBack(rhs);
        return this;
    }

/// ditto
    DList opOpAssign(string op)(DList rhs)
    if (op == "~")
    {
        return this ~= rhs[];
    }

/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/
/+                        BEGIN INSERT FUNCTIONS HERE                         +/
/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/

/**
Inserts $(D stuff) to the front/back of the container. $(D stuff) can be a
value convertible to $(D T) or a range of objects convertible to $(D
T). The stable version behaves the same, but guarantees that ranges
iterating over the container are never invalidated.

Returns: The number of elements inserted

Complexity: $(BIGOH log(n))
     */
    size_t insertFront(Stuff)(Stuff stuff)
    {
        return insertBeforeNode(_first, stuff);
    }

    /// ditto
    size_t insertBack(Stuff)(Stuff stuff)
    {
        return insertBeforeNode(null, stuff);
    }

    /// ditto
    alias insert = insertBack;

    /// ditto
    alias stableInsert = insert;

    /// ditto
    alias stableInsertFront = insertFront;

    /// ditto
    alias stableInsertBack = insertBack;

/**
Inserts $(D stuff) after range $(D r), which must be a non-empty range
previously extracted from this container.

$(D stuff) can be a value convertible to $(D T) or a range of objects
convertible to $(D T). The stable version behaves the same, but
guarantees that ranges iterating over the container are never
invalidated.

Elements are not actually removed from the chain, but the $(D DList)'s,
first/last pointer is advanced.

Returns: The number of values inserted.

Complexity: $(BIGOH k + m), where $(D k) is the number of elements in
$(D r) and $(D m) is the length of $(D stuff).
     */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    {
        Node* n = (r._first) ? r._first : _first;
        return insertBeforeNode(n, stuff);
    }

    /// ditto
    alias stableInsertBefore = insertBefore;

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        Node* n = (r._last) ? r._last._next : null;
        return insertBeforeNode(n, stuff);
    }

    /// ditto
    alias stableInsertAfter = insertAfter;

/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/
/+                        BEGIN REMOVE FUNCTIONS HERE                         +/
/+ ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ +/

/**
Picks one value from the front of the container, removes it from the
container, and returns it.

Elements are not actually removed from the chain, but the $(D DList)'s,
first/last pointer is advanced.

Precondition: $(D !empty)

Returns: The element removed.

Complexity: $(BIGOH 1).
     */
    T removeAny()
    {
        assert(!empty, "DList.removeAny: List is empty");
        auto result = move(back);
        _last = _last._prev;
        if (_last is null)
        {
            _first = null;
        }
        return result;
    }
    /// ditto
    alias stableRemoveAny = removeAny;

/**
Removes the value at the front/back of the container. The stable version
behaves the same, but guarantees that ranges iterating over the
container are never invalidated.

Elements are not actually removed from the chain, but the $(D DList)'s,
first/last pointer is advanced.

Precondition: $(D !empty)

Complexity: $(BIGOH 1).
     */
    void removeFront()
    {
        assert(!empty, "DList.removeFront: List is empty");
        _first = _first._next;
        if (_first is null)
        {
            _last = null;
        }
    }

    /// ditto
    alias stableRemoveFront = removeFront;

    /// ditto
    void removeBack()
    {
        assert(!empty, "DList.removeBack: List is empty");
        _last = _last._prev;
        if (_last is null)
        {
            _first = null;
        }
    }

    /// ditto
    alias stableRemoveBack = removeBack;

/**
Removes $(D howMany) values at the front or back of the
container. Unlike the unparameterized versions above, these functions
do not throw if they could not remove $(D howMany) elements. Instead,
if $(D howMany > n), all elements are removed. The returned value is
the effective number of elements removed. The stable version behaves
the same, but guarantees that ranges iterating over the container are
never invalidated.

Elements are not actually removed from the chain, but the $(D DList)'s,
first/last pointer is advanced.

Returns: The number of elements removed

Complexity: $(BIGOH howMany * log(n)).
     */
    size_t removeFront(size_t howMany)
    {
        size_t result;
        while (_first && result < howMany)
        {
            _first = _first._next;
            ++result;
        }
        if (_first is null)
        {
            _last = null;
        }
        return result;
    }

    /// ditto
    alias stableRemoveFront = removeFront;

    /// ditto
    size_t removeBack(size_t howMany)
    {
        size_t result;
        while (_last && result < howMany)
        {
            _last = _last._prev;
            ++result;
        }
        if (_last is null)
        {
            _first = null;
        }
        return result;
    }

    /// ditto
    alias stableRemoveBack = removeBack;

/**
Removes all elements belonging to $(D r), which must be a range
obtained originally from this container.

This function actually removes the elements from the chain. This is the
only function that may invalidate a range, as it cuts the chain of elements:
*Ranges (and other DList) that contain $(D r) or that are inside $(D r),
as well a $(D r) itself, are never invalidated.
*Ranges (and other DList) which partially overlap with $(D r) will be cut,
and invalidated.

Returns: A range spanning the remaining elements in the container that
initially were right after $(D r).

Complexity: $(BIGOH 1)
     */
    Range remove(Range r)
    {
        if (r.empty)
        {
            return r;
        }
        assert(!empty, "DList.remove: Range is empty");

        //Note about the unusual complexity here:
        //The first and last nodes are not necessarilly the actual last nodes
        //of the "chain".
        //If we merelly excise the range from the chain, we can run into odd behavior,
        //in particlar, when the range's front and/or back coincide with the List's...

        Node* before = r._first._prev;
        Node* after = r._last._next;

        Node* oldFirst = _first;
        Node* oldLast = _last;

        if (before)
        {
            if (after)
            {
                before._next = after;
                after._prev = before;
            }
            if (_first == r._first)
                _first = (oldLast != r._last) ? after : null ;
        }
        else
        {
            assert(oldFirst == r._first, "Dlist.remove: Range is not part of the list");
            _first = (oldLast != r._last) ? after : null ;
        }

        if (after)
        {
            if (before)
            {
                after._prev = before;
                before._next = after;
            }
            if (_last == r._last)
                _last = (oldFirst != r._first) ? before : null ;
        }
        else
        {
            assert(oldLast == r._last, "Dlist.remove: Range is not part of the list");
            _last = (oldFirst != r._first) ? before : null ;
        }

        return Range(after, _last);
    }

    /// ditto
    Range linearRemove(Range r)
    {
         return remove(r);
    }

/**
$(D linearRemove) functions as $(D remove), but also accepts ranges that are
result the of a $(D take) operation. This is a convenient way to remove a
fixed amount of elements from the range.

Complexity: $(BIGOH r.walkLength)
     */
    Range linearRemove(Take!Range r)
    {
        if (r.empty)
            return Range(null,null);
        assert(r.source._first);

        Node* first = r.source._first;
        Node* last = void;
        do
        {
            last = r.source._first;
            r.popFront();
        } while ( !r.empty );

        return remove(Range(first, last));
    }

    /// ditto
    alias stableRemove = remove;
    /// ditto
    alias stableLinearRemove = linearRemove;

private:
    // Helper: insert $(D stuff) before Node $(D n). If $(D n) is $(D null) then insert at end.
    size_t insertBeforeNode(Stuff)(Node* n, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        size_t result;
        if(stuff.empty) return result;

        Node* first;
        Node* last;
        //scope block
        {
            auto item = stuff.front;
            stuff.popFront();
            last = first = new Node(item, null, null);
            ++result;
        }
        foreach (item; stuff)
        {
            last = new Node(item, last, null);
            ++result;
        }

        //We have created a first-last chain. Now we insert it.
        if(!_first)
        {
            _first = first;
            _last = last;
        }
        else
        {
            assert(_last);
            if(n)
            {
                if(n._prev)
                {
                    n._prev._next = first;
                    first._prev = n._prev;
                }
                n._prev = last;
                last._next = n;
                if(n is _first)
                  _first = first;
            }
            else
            {
                if(_last._next)
                {
                    _last._next._prev = last;
                    last._next = _last._next;
                }
                _last._next = first;
                first._prev = _last;
                _last = last;
            }
        }
        assert(_first);
        assert(_last);
        return result;
    }

    // Helper: insert $(D stuff) before Node $(D n). If $(D n) is $(D null) then insert at end.
    size_t insertBeforeNode(Stuff)(Node* n, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        Stuff[] stuffs = (&stuff)[0 .. 1];
        return insertBeforeNode(n, stuffs);
    }
}

unittest
{
    auto a = DList!int([3, 4]); //Create a new chain
    auto b = a; //Point to the same chain
    // (3 - 4)
    assert(a[].equal([3, 4]));
    assert(b[].equal([3, 4]));

    b.stableInsertFront(1); //insert before of b
    b.stableInsertBack(5); //insert after of b
    // (2 - (3 - 4) - 5)
    assert(a[].equal([3, 4])); //a is not changed
    assert(b[].equal([1, 3, 4, 5])); // but b is changed

    a.stableInsertFront(2); //insert in front of a, this will insert "inside" the chain
    // (1 - (2 - 3 - 4) - 5)
    assert(a[].equal([2, 3, 4])); //a is modified
    assert(b[].equal([1, 2, 3, 4, 5])); //and so is b;

    a.remove(a[]); //remove all the elements of a: This will cut them from the chain;
    // (1 - 5)
    assert(a[].empty); //a is empty
    assert(b[].equal([1, 5])); //b has lost some of its elements;

    a.insert(2); //insert in a. This will create a new chain
    // (2)
    // (1 - 5)
    assert(a[].equal([2])); //a is a new chain
    assert(b[].equal([1, 5])); //b is unchanged;
}

unittest
{
    //Tests construction signatures
    alias IntList = DList!int;
    auto a0 = IntList();
    auto a1 = IntList(0);
    auto a2 = IntList(0, 1);
    auto a3 = IntList([0]);
    auto a4 = IntList([0, 1]);

    assert(a0[].empty);
    assert(equal(a1[], [0]));
    assert(equal(a2[], [0, 1]));
    assert(equal(a3[], [0]));
    assert(equal(a4[], [0, 1]));
}

unittest
{
    alias IntList = DList!int;
    IntList list = IntList([0,1,2,3]);
    assert(equal(list[],[0,1,2,3]));
    list.insertBack([4,5,6,7]);
    assert(equal(list[],[0,1,2,3,4,5,6,7]));

    list = IntList();
    list.insertFront([0,1,2,3]);
    assert(equal(list[],[0,1,2,3]));
    list.insertFront([4,5,6,7]);
    assert(equal(list[],[4,5,6,7,0,1,2,3]));
}

unittest
{
    alias IntList = DList!int;
    IntList list = IntList([0,1,2,3]);
    auto range = list[];
    for( ; !range.empty; range.popFront())
    {
        int item = range.front;
        if (item == 2)
        {
            list.stableLinearRemove(take(range,1));
            break;
        }
    }
    assert(equal(list[],[0,1,3]));

    list = IntList([0,1,2,3]);
    range = list[];
    for( ; !range.empty; range.popFront())
    {
        int item = range.front;
        if (item == 2)
        {
            list.stableLinearRemove(take(range,2));
            break;
        }
    }
    assert(equal(list[],[0,1]));

    list = IntList([0,1,2,3]);
    range = list[];
    for( ; !range.empty; range.popFront())
    {
        int item = range.front;
        if (item == 0)
        {
            list.stableLinearRemove(take(range,2));
            break;
        }
    }
    assert(equal(list[],[2,3]));

    list = IntList([0,1,2,3]);
    range = list[];
    for( ; !range.empty; range.popFront())
    {
        int item = range.front;
        if (item == 1)
        {
            list.stableLinearRemove(take(range,2));
            break;
        }
    }
    assert(equal(list[],[0,3]));
}

unittest
{
    auto dl = DList!string(["a", "b", "d"]);
    dl.insertAfter(dl[], "e"); // insert at the end
    assert(equal(dl[], ["a", "b", "d", "e"]));
    auto dlr = dl[];
    dlr.popBack(); dlr.popBack();
    dl.insertAfter(dlr, "c"); // insert after "b"
    assert(equal(dl[], ["a", "b", "c", "d", "e"]));
}

unittest
{
    auto dl = DList!string(["a", "b", "d"]);
    dl.insertBefore(dl[], "e"); // insert at the front
    assert(equal(dl[], ["e", "a", "b", "d"]));
    auto dlr = dl[];
    dlr.popFront(); dlr.popFront();
    dl.insertBefore(dlr, "c"); // insert before "b"
    assert(equal(dl[], ["e", "a", "c", "b", "d"]));
}

unittest
{
    auto d = DList!int([1, 2, 3]);
    d.front = 5; //test frontAssign
    assert(d.front == 5);
    auto r = d[];
    r.back = 1;
    assert(r.back == 1);
}

unittest
{
    auto d = DList!int([1, 2, 3]);
    d.front = 5; //test frontAssign
    assert(d.front == 5);
    auto r = d[];
    r.back = 1;
    assert(r.back == 1);
}

unittest
{
    auto a = DList!int();
    assert(a.removeFront(10) == 0);
    a.insert([1, 2, 3]);
    assert(a.removeFront(10) == 3);
    assert(a[].empty);
}

unittest
{
    //Verify all flavors of ~
    auto a = DList!int();
    auto b = DList!int();
    auto c = DList!int([1, 2, 3]);
    auto d = DList!int([4, 5, 6]);

    assert((a ~ b[])[].empty);

    assert((c ~ d[])[].equal([1, 2, 3, 4, 5, 6]));
    assert(c[].equal([1, 2, 3]));
    assert(d[].equal([4, 5, 6]));

    assert((c[] ~ d)[].equal([1, 2, 3, 4, 5, 6]));
    assert(c[].equal([1, 2, 3]));
    assert(d[].equal([4, 5, 6]));

    a~=c[];
    assert(a[].equal([1, 2, 3]));
    assert(c[].equal([1, 2, 3]));

    a~=d[];
    assert(a[].equal([1, 2, 3, 4, 5, 6]));
    assert(d[].equal([4, 5, 6]));

    a~=[7, 8, 9];
    assert(a[].equal([1, 2, 3, 4, 5, 6, 7, 8, 9]));

    //trick test:
    auto r = c[];
    c.removeFront();
    c.removeBack();
    c~=d[];
    assert(c[].equal([2, 4, 5, 6]));
    assert(r.equal([1, 2, 4, 5, 6, 3]));
}

unittest
{
    //8905
    auto a = DList!int([1, 2, 3, 4]);
    auto r = a[];
    a.stableRemoveBack();
    a.stableInsertBack(7);
    assert(a[].equal([1, 2, 3, 7]));
    assert(r.equal([1, 2, 3, 7, 4]));
}
