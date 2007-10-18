module std.slist;

import std.contracts; // enforce
import std.stdio;
import std.conv; // testing

/////////////////////////////////////////////////////////////////////////////////
/**
 * Singly-linked list. The intent is to make it as efficient as the
 * simplest hand-coded list. Therefore, no tricks are employed - no
 * phantom node, no circularity, no fat iterators, just a straight
 * list of nodes terminated by $(D_PARAM null). Therefore, $(D_PARAM
 * SList) only supports forward iteration, does not have access to its
 * last element, and only supports adding elements to the front or
 * after the current iterator.
 */
struct SList(T) {
private:
    struct Node
    {
        T value;
        //node* prev;
        Node* next;
    }
    Node *root;
public:
    alias T Value;
    //Alias T* Pointer;
    //Alias T Reference;
    //Alias T ConstReference;
    alias .Iterator!(SList) Iterator;

    /**
     * Builds a list of $(D_PARAM length) elements, initialized with
     * $(D_PARAM value). */
    static SList opCall(size_t length, T value)
    {
        auto nodes = new Node[length];
        nodes[0].value = value;
        foreach (ref e; nodes[1 .. $])
        {
            e.value = value;
            (&e)[-1].next = &e;
        }
        SList result;
        result.root = &nodes[0];
        return result;
    }

    // todo: eliminate this duplication
    /**
     * Build a list of $(D_PARAM length) elements, initialized with
     * $(D_PARAM T.init). */
    static SList opCall(size_t length = 0)
    {
        if (!length)
        {
            SList result;
            return result;
        }
        auto nodes = new Node[length];
        foreach (ref e; nodes[1 .. $])
        {
            (&e)[-1].next = &e;
        }
        SList result;
        result.root = &nodes[0];
        return result;
    }

//     static SList opCall(U)(Iterator!(U) b, Iterator!(U) e)
//     {
//     }            

//     void opAssign(U)(List!(U) rhs)
//     {
//         for (auto i = begin(rhs); i != end(rhs); next(i))
//         {
//         }
//     }

    /**
     * Compares a list with an array for element-wise equality.
     */ 
    int opEquals(U)(const(U)[] v)
    {
        size_t j = 0;
        for (auto i = begin(*this); i != end(*this); next(i))
        {
            if (v.length <= j || v[j++] != get(i)) return false;
        }
        return true;
    }
}

template Ref(T)
{
    alias T Ref;
}

/**
 * Returns an iterator to the head of the list.
 */ 
Iterator!(SList!(T)) begin(T)(ref SList!(T) lst)
{
    return Iterator!(SList!(T))(lst.root);
}

/**
 * Returns an iterator after the end of the list ($(D_PARAM null) in fact).
 */ 
Iterator!(SList!(T)) end(T)(ref SList!(T) lst)
{
    return Iterator!(SList!(T))(null);
}

/**
 * Returns the first element in the list. Precondition: $(D_PARAM
 * !isEmpty(lst)).
 */ 
Ref!(T) front(T)(ref SList!(T) lst)
in
{
    enforce(lst.root, "Attempting to fetch the front of an empty list");
}
body
{
    return lst.root.value;
}

/**
 * Pushes $(D_PARAM elems) to the front of the list $(D_PARAM lst),
 * and returns an iterator to the root of the list.
 */ 
Iterator!(SList!(T)) pushFront(T, U...)(ref SList!(T) lst, U elems)
{
    auto newNodes = new lst.Node[elems.length];
    foreach (i, e; elems)
    {
        newNodes[i].value = e;
        if (i + 1 < elems.length) newNodes[i].next = &newNodes[i + 1];
    }
    newNodes[$ - 1].next = lst.root;
    return Iterator!(SList!(T))(lst.root = newNodes.ptr);
}
 
/**
 * True if and only if $(D_PARAM lst) is empty.
 */ 
bool isEmpty(T)(ref SList!(T) lst)
{
    return lst.root == null;
}

unittest
{
    SList!(int) lst;
    assert(isEmpty(lst));
    pushFront(lst, 42);
    assert(!isEmpty(lst));
    assert(front(lst) == 42);
}

/**
 * List iterator. Models forward iteration.
 */

struct Iterator(L : SList!(T), T)
{
    private L.Node* crt;
    static Iterator opCall(L.Node* n) {
        Iterator r;
        r.crt = n;
        return r;
    }
    static Iterator opCall(L lst) {
        Iterator r;
        r.crt = lst.root;
        return r;
    }
    bool opEquals(Iterator rhs) { return crt == rhs.crt; }
}

/**
 * Read the value pointed to by the iterator.
 */
T get(T)(Iterator!(SList!(T)) i)
{ 
    return assert(i.crt), i.crt.value; 
}

/**
 * Assign to the value pointed to by the iterator.
 */
T set(T, U)(ref Iterator!(SList!(T)) i, U rhs)
{ 
    return assert(i.crt), i.crt.value = rhs; 
}

/**
 * Increment the iterator.
 */
void next(T)(ref Iterator!(SList!(T)) i)
{ 
    assert(i.crt);
    i.crt = i.crt.next; 
}

unittest
{
    {
        // test uninitialized list
        auto lst = SList!(double)(42);
        uint counter = 0;
        for (auto i = begin(lst); i != end(lst); next(i))
        {
            assert(get(i) != get(i));
            ++counter;
        }
    }
    auto lst = SList!(double)(42, 5);
    uint counter = 0;
    for (auto i = begin(lst); i != end(lst); next(i))
    {
        assert(get(i) == 5);
        ++counter;
    }
    counter = 0;
    for (auto i = begin(lst); i != end(lst); next(i))
    {
        assert(get(i) == 5);
        if (counter & 1) set(i, 234);
        ++counter;
    }
    assert(counter == 42);
    counter = 0;
    for (auto i = begin(lst); i != end(lst); next(i))
    {
        if (counter & 1) assert(get(i) == 234);
        else assert(get(i) == 5);
        ++counter;
    }
    assert(counter == 42);
}

/**
 * Pops the element in the front of the list $(D_PARAM lst).
 */ 
void popFront(T)(ref SList!(T) lst)
{
    assert(lst.root);
    lst.root = lst.root.next;
}

unittest
{
    auto lst = SList!(double)(1, 5);
    assert(front(lst) == 5);
    popFront(lst);
    assert(isEmpty(lst));
}

/**
 * Inserts an element with value $(D_PARAM value) in $(D_PARAM lst)
 * after $(D_PARAM i). Returns an iterator to the element just inserted.
 */ 
Iterator!(SList!(T)) insertAfter(T, U)(ref SList!(T) lst,
                                       Iterator!(SList!(T)) i, U value)
{
    assert(i.crt);
    auto newNode = new lst.Node;
    newNode.value = value;
    newNode.next = i.crt.next;
    i.crt.next = newNode;
    return Iterator!(SList!(T))(newNode);
}

unittest
{
    auto lst = SList!(double)(1, 5);
    assert(front(lst) == 5);
    popFront(lst);
    assert(isEmpty(lst));
    pushFront(lst, 6);
    auto i = begin(lst);
    insertAfter(lst, i, 43);
    assert(get(i) == 6);
    next(i);
    assert(get(i) == 43);
    next(i);
    assert(i == end(lst));
}

/**
 * Pushes a range to the front of the list $(D_PARAM lst), and returns
 * an iterator to the last element inserted.
 */ 
void insertAfter(T, U)(ref SList!(T) lst, Iterator!(SList!(T)) i,
                       Iterator!(U) begin, Iterator!(U) end)
{
    for (; begin != end; next(begin))
    {
        i = insertAfter(lst, i, get(begin));
    }
}

unittest
{
    auto lst = SList!(double)(2, 5);
    auto lst1 = SList!(int)(2, 44);
    auto i = begin(lst);
    //next(i);
    insertAfter(lst, i, begin(lst1), end(lst1));
    assert(get(i) == 5);
    next(i);
    assert(get(i) == 44);
    next(i);
    assert(get(i) == 44);
    next(i);
    assert(get(i) == 5);
    next(i);
    assert(i == end(lst));
}

/**
 * Pushes $(D_PARAM n) copies of $(D_PARAM value) to the front of the
 * list $(D_PARAM lst), and returns an iterator to the last element
 * inserted.
 */ 
void insertAfter(T, U)(ref SList!(T) lst, Iterator!(SList!(T)) i,
                       size_t n, U value)
{
    for (; n-- > 0; )
    {
        i = insertAfter(lst, i, value);
    }
}

unittest
{
    auto lst = SList!(double)(2, 5);
    auto lst1 = SList!(int)(2, 44);
    auto i = begin(lst);
    //next(i);
    insertAfter(lst, i, 2u, 44);
    assert(get(i) == 5);
    next(i);
    assert(get(i) == 44);
    next(i);
    assert(get(i) == 44);
    next(i);
    assert(get(i) == 5);
    next(i);
    assert(i == end(lst));
}

/**
 * Erases the element after the one pointed to by $(D_PARAM i).
 */ 
Iterator!(SList!(T)) eraseAfter(T)(ref SList!(T), Iterator!(SList!(T)) i)
{
    assert(i.crt);
    assert(i.crt.next);
    i.crt.next = i.crt.next.next;
    return i;
}

unittest
{
    auto lst = SList!(double)();
    pushFront(lst, 1, 2, 3);
    auto i = begin(lst);
    eraseAfter(lst, i);
    assert(get(i) == 1);
    next(i);
    assert(get(i) == 3);
    next(i);
    assert(i == end(lst));
}

/**
 * Erases the elements from the element after the one pointed to by
 * $(D_PARAM begin), up to (and including) the one pointed to by
 * $(D_PARAM end).
 */ 
Iterator!(SList!(T)) eraseAfter(T)(ref SList!(T) lst, Iterator!(SList!(T)) begin,
                                   Iterator!(SList!(T)) end)
{
    begin.crt.next = end.crt.next;
    return begin; 
}

unittest
{
    auto lst = SList!(double)();
    pushFront(lst, 1, 2, 3, 4);
    auto i = begin(lst), j = i;
    eraseAfter(lst, i, j);
    assert(lst == [ 1, 2, 3, 4 ], to!(string)(front(lst)));
    next(j);
    eraseAfter(lst, i, j);
    assert(lst == [ 1, 3, 4 ], to!(string)(front(lst)));
}

/**
 * Erases the elements from the element after the one pointed to by
 * $(D_PARAM begin), up to (and including) the one pointed to by
 * $(D_PARAM end).
 */ 
void clear(T)(ref SList!(T) lst)
{
    lst.root = null;
}

unittest
{
    auto lst = SList!(double)();
    pushFront(lst, 1, 2, 3);
    clear(lst);
    assert(isEmpty(lst));
}

/**
 * Inserts or erases elements at the front of $(D_PARAM lst) such that
 * the size becomes $(D_PARAM n).
 */ 
void resize(T)(ref SList!(T) lst, size_t n)
{
    resize(lst, n, T.init);
}

/** ditto
 */ 
void resize(T, U)(ref SList!(T) lst, size_t n, U value)
{
    auto b = begin(lst);
    if (b == end(lst))
    {
        // empty list
        lst = SList!(T)(n, value);
    }
    else
    {
        size_t length = 1;
        for (; b.crt.next !is null; next(b))
        {
            ++length;
        }
        if (length < n)
        {
            n -= length;
            auto tail = SList!(T)(n, value);
            b.crt.next = tail.root;
        }
    }
}

unittest
{
    auto lst = SList!(double)();
    pushFront(lst, 1, 2, 3);
    // @@@ BUG IN COMPILER: SHOULD ACCEPT CALL WITHOUT 'u'
    resize(lst, 2u);
    assert(lst == [ 1, 2, 3 ]);
    resize(lst, 3u);
    assert(lst == [ 1, 2, 3 ]);
    resize(lst, 5u, 42);
    assert(lst == [ 1.0, 2, 3, 42, 42 ]);
}

/**
 * Computes the distance between two iterators in linear or better time.
 */ 
size_t distanceLin(T)(Iterator!(T) from, Iterator!(T) to)
{
    size_t result;
    for (; from != to; next(from))
    {
        ++result;
    }
    return result;
}

unittest
{
    auto lst = SList!(double)(5, 667.45);
    assert(distanceLin(begin(lst), end(lst)) == 5);
}

/**
 * Computes the last valid iterator before $(D_PARAM to) in linear or
 * better time.
 */ 
Iterator!(T) lastLin(T)(Iterator!(T) from, Iterator!(T) to)
{
    if (from == to) return from;
    for (;;)
    {
        auto save = from;
        next(from);
        if (from == to) return save;
    }
}

unittest
{
    SList!(double) lst;
    pushFront(lst, 5, 10, 23, 667.45);
    assert(get(lastLin(begin(lst), end(lst))) == 667.45);
}

/**
 * Reads the value pointed to by the iterator, and increments the iterator.
 */
bool getNext(It : Iterator!(List!(T)))(It i, ref T target)
{
    if (!i.crt) return false;
    target = i.crt.value;
    next(i);
    return true;
}

/+

/////////////////////////////////////////////////////////////////////////////////
size_t size(T)(inout SList!(T) lst) {
    //if (lst.size != lst.size.max) return lst.size;
    // compute the size
    //lst.size = 0;
    auto size = 0;
    for (auto n = lst.root; n; n = n.next) {
        // ++lst.size;
        ++size;
    }
    //return lst.size;
    return size;
}

unittest {
    SList!(int) list;
    assert(size(list) == 0);
    push_back(list, 1);
    assert(size(list) == 1);
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator begin(T)(inout SList!(T) list) {
    return list.iterator(list.root);
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator end(T)(inout SList!(T) list) {
    return list.iterator(null);
}

/////////////////////////////////////////////////////////////////////////////////
bool is_empty(T)(inout SList!(T) lst) {
    return lst.root == null;
}

unittest {
    SList!(int) list;
    assert(is_empty(list));
    list.iterator i = begin(list);
    assert(i.done());
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator push_front(T, U)(inout SList!(T) lst, U elem) {
    auto newNode = new lst.node;
    newNode.value = elem;
    if (!lst.root) {
        newNode.prev = newNode;
        newNode.next = null;
    } else {
        assert(lst.root.prev);
        newNode.prev = lst.root.prev;
        newNode.next = lst.root;
        lst.root.prev = newNode;
    }
    return lst.iterator(lst.root = newNode);
}

unittest {
    SList!(int) list;
    assert(is_empty(list));
    //
    list.iterator i = begin(list);
    assert(i.done());
    //
    push_front(list, 1);
    i = begin(list);
    assert(!i.done);
    assert(i.get == 1);
    i.next();
    assert(i.done);
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator push_back(T, U)(inout SList!(T) lst, U elem) {
    if (!lst.root) return push_front(lst, elem);
    auto newNode = new lst.node;
    newNode.value = elem;
    auto ante = lst.root.prev;
    assert(ante && ante.next == null);
    newNode.prev = ante;
    ante.next = newNode;
    return lst.iterator(lst.root.prev = newNode);
}

unittest {
    SList!(int) list;
    assert(size(list) == 0);
    assert(is_empty(list));
    push_back(list, 1);
    assert(size(list) == 1);
    assert(!is_empty(list));
}

/////////////////////////////////////////////////////////////////////////////////
T back(T)(inout SList!(T) lst) {
    assert(lst.root && lst.root.prev);
    return lst.root.prev.value;
}

unittest {
    SList!(int) list;
    push_back(list, 1);
    assert(size(list) == 1);
    assert(!is_empty(list));
    assert(back(list) == 1);
}

/////////////////////////////////////////////////////////////////////////////////
T front(T)(inout SList!(T) lst) {
    assert(lst.root);
    return lst.root.value;
}

unittest {
    SList!(int) list;
    push_back(list, 1);
    assert(front(list) == 1);
    push_back(list, 2);
    assert(front(list) == 1);
}

/////////////////////////////////////////////////////////////////////////////////
void pop_front(T)(inout SList!(T) lst) {
    enforce(!is_empty(lst));
    auto yank = lst.root;
    auto newRoot = yank.next;
    if (!newRoot) {
        // last mohican
        lst.root = null;
    } else {
        // two or more elements
        newRoot.prev = yank.prev;
        lst.root = newRoot;
    }
}

unittest {
    SList!(int) list;
    push_back(list, 1);
    push_back(list, 2);
    pop_front(list);
    assert(front(list) == 2 && back(list) == 2);
}

/////////////////////////////////////////////////////////////////////////////////
void pop_back(T)(inout SList!(T) lst) {
    enforce(!is_empty(lst));
    auto yank = lst.root.prev;
    auto newBack = yank.prev;
    if (yank == newBack) {
        // remove the last element
        lst.root = null;
        return;
    }
    lst.root.prev = newBack;
    newBack.next = null;
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator insert(T, Iter, U)
(inout SList!(T) lst, Iter i, U elem) {
    if (lst.root == i.crt) return push_front(lst, elem);
    if (!i.crt) return push_back(lst, elem);
    // Now for the "real" case: i is somewhere in the middle of the list
    auto newNode = new lst.node;
    // fill the new node correctly for insertion _before_ i.crt
    auto post = i.crt;
    auto ante = post.prev;
    newNode.value = elem;
    newNode.next = post;
    newNode.prev = ante;
    post.prev = newNode;
    ante.next = newNode;
    return lst.iterator(newNode);
}

/////////////////////////////////////////////////////////////////////////////////
SList!(T).iterator erase(T, Iter)
(inout SList!(T) lst, Iter i) {
    enforce(lst.root && i.crt);
    if (lst.root == i.crt) {
        pop_front(lst);
        return lst.iterator(lst.root);
    }
    if (i.crt == lst.root.prev) {
        pop_back(lst);
        return lst.iterator(null);
    }
    // Now for the "real" case: i is somewhere in the middle of the list
    auto post = i.crt.next;
    auto ante = i.crt.prev;
    post.prev = ante;
    ante.next = post;
    return lst.iterator(post);
}

struct CircularQueue(T) {
private SList!(T) store;
    private size_t size;
    // 
    static CircularQueue opCall(uint size, T init = T.init) {
        CircularQueue!(T) result;
        result.store = SList!(T)(size, init);
        result.size = size;
        return result;
    }
    struct iterator {
        SList!(T).iterator val;
        void next() {
            val.next();
        }
        T get() {
            return val.get;
        }
    }
    iterator begin() {
        iterator result;
        result.val = .begin(this.store);
        return result;
    }
    iterator end() {
        iterator result;
        result.val = .end(this.store);
        return result;
    }
}

T front(T, U=void)(inout CircularQueue!(T) lst) {
    return front(lst.store);
}

void push(T)(inout CircularQueue!(T) lst, T element) {
    // just move the root!
    lst.store.root.value = element;
    // fix the asymmetry of the last element
    assert(!lst.store.root.prev.next);
    lst.store.root.prev.next = lst.store.root;
    lst.store.root = lst.store.root.next;
    lst.store.root.prev.next = null;
    lst.store.check();
}

size_t size(T, U=void)(inout CircularQueue!(T) lst) {
    return lst.size;
}

/////////////////////////////////////////////////////////////////////////////////
import std.random;
import std.string;
import std.stdio;

unittest {
    SList!(uint) list;
    uint[] witness;

    void PositionRandomly(out list.iterator iter, out uint advance) {
        if (!witness.length) return;
        advance = rand() % witness.length;
        iter = begin(list);
        for (auto j = 0; j != advance; ++j) {
            iter.next;
            assert(!iter.done);
        }
        assert(iter.get == witness[advance], toString(advance));
    }

    for (auto i = 1_000_000; i > 0; --i) {
        list.check();
        list.iterator iter2 = begin(list);
        for (uint j = 0; j != witness.length; ++j, iter2.next) {
            assert(witness[j] == iter2.get);
        }
        writef(i, "\r");
        switch (rand() & 7) {
        case 0:
            witness ~= rand();
            push_back(list, witness[$-1]);
            break;
        case 1:
            witness = rand() ~ witness;
            push_front(list, witness[0]);
            break;
        case 2: 
            if (witness.length) {
                witness = witness[0 .. $ - 1];
                pop_back(list);
            }
            break;
        case 3:
            if (witness.length) {
                witness = witness[1 .. $];
                pop_front(list);
            }
            break;
        case 4:
            if (witness.length) {
                list.iterator iter;
                uint advance;
                PositionRandomly(iter, advance);
                witness = witness[0 .. advance] ~ rand() ~ witness[advance .. $];
                insert(list, iter, witness[advance]);
            }
            break;
        case 5:
            if (witness.length) {
                list.iterator iter;
                uint advance;
                PositionRandomly(iter, advance);
                witness = witness[0 .. advance] ~ witness[advance + 1 .. $];
                erase(list, iter);
            }
            break;
        case 6:
        case 7:
        default: ;//assert(false);
        }
    }
    writefln("wyda           ");
}

// T enforce(T)(T expression, char[] message = "Enforcement failed") {
//   if (!expression) throw new Exception(message);
//   return expression;
// }

version (selftest) {
    void main() {}
}

+/
