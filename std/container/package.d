// Written in the D programming language.

/**
Defines generic containers.

Source: $(PHOBOSSRC std/container/_package.d)
Macros:
WIKI = Phobos/StdContainer
TEXTWITHCOMMAS = $0

Copyright: Red-black tree code copyright (C) 2008- by Steven Schveighoffer. Other code
copyright 2010- Andrei Alexandrescu. All rights reserved by the respective holders.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Steven Schveighoffer, $(WEB erdani.com, Andrei Alexandrescu)

$(BOOKTABLE $(TEXTWITHCOMMAS Container primitives. A _container need not
implement all primitives, but if a primitive is implemented, it must
support the syntax described in the $(B syntax) column with the semantics
described in the $(B description) column, and it must not have worse worst-case
complexity than denoted in big-O notation in the $(BIGOH &middot;) column.
Below, $(D C) means a _container type, $(D c) is a value of _container
type, $(D n$(SUBx)) represents the effective length of value $(D x),
which could be a single element (in which case $(D n$(SUB x)) is $(D 1)),
a _container, or a range.),

$(TR $(TH Syntax) $(TH $(BIGOH &middot;)) $(TH Description))

$(TR $(TDNW $(D C(x))) $(TDNW $(D n$(SUB x))) $(TD Creates a
_container of type $(D C) from either another _container or a range.))

$(TR $(TDNW $(D c.dup)) $(TDNW $(D n$(SUB c))) $(TD Returns a
duplicate of the _container.))

$(TR $(TDNW $(D c ~ x)) $(TDNW $(D n$(SUB c) + n$(SUB x))) $(TD
Returns the concatenation of $(D c) and $(D r). $(D x) may be a single
element or an input range.))

$(TR $(TDNW $(D x ~ c)) $(TDNW $(D n$(SUB c) + n$(SUB x))) $(TD
Returns the concatenation of $(D x) and $(D c).  $(D x) may be a
single element or an input range type.))

$(LEADINGROW Iteration)

$(TR  $(TD $(D c.Range)) $(TD) $(TD The primary range
type associated with the _container.))

$(TR $(TD $(D c[])) $(TDNW $(D log n$(SUB c))) $(TD Returns a range
iterating over the entire _container, in a _container-defined order.))

$(TR $(TDNW $(D c[a .. b])) $(TDNW $(D log n$(SUB c))) $(TD Fetches a
portion of the _container from key $(D a) to key $(D b).))

$(LEADINGROW Capacity)

$(TR $(TD $(D c.empty)) $(TD $(D 1)) $(TD Returns $(D true) if the
_container has no elements, $(D false) otherwise.))

$(TR  $(TD $(D c.length)) $(TDNW $(D log n$(SUB c))) $(TD Returns the
number of elements in the _container.))

$(TR $(TDNW $(D c.length = n)) $(TDNW $(D n$(SUB c) + n)) $(TD Forces
the number of elements in the _container to $(D n). If the _container
ends up growing, the added elements are initialized in a
_container-dependent manner (usually with $(D T.init)).))

$(TR $(TD $(D c.capacity)) $(TDNW $(D log n$(SUB c))) $(TD Returns the
maximum number of elements that can be stored in the _container
without triggering a reallocation.))

$(TR $(TD $(D c.reserve(x))) $(TD $(D n$(SUB c))) $(TD Forces $(D
capacity) to at least $(D x) without reducing it.))

$(LEADINGROW Access)

$(TR $(TDNW $(D c.front)) $(TDNW $(D log n$(SUB c))) $(TD Returns the
first element of the _container, in a _container-defined order.))

$(TR $(TDNW $(D c.moveFront)) $(TDNW $(D log n$(SUB c))) $(TD
Destructively reads and returns the first element of the
_container. The slot is not removed from the _container; it is left
initialized with $(D T.init). This routine need not be defined if $(D
front) returns a $(D ref).))

$(TR $(TDNW $(D c.front = v)) $(TDNW $(D log n$(SUB c))) $(TD Assigns
$(D v) to the first element of the _container.))

$(TR $(TDNW $(D c.back)) $(TDNW $(D log n$(SUB c))) $(TD Returns the
last element of the _container, in a _container-defined order.))

$(TR $(TDNW $(D c.moveBack)) $(TDNW $(D log n$(SUB c))) $(TD
Destructively reads and returns the last element of the
container. The slot is not removed from the _container; it is left
initialized with $(D T.init). This routine need not be defined if $(D
front) returns a $(D ref).))

$(TR $(TDNW $(D c.back = v)) $(TDNW $(D log n$(SUB c))) $(TD Assigns
$(D v) to the last element of the _container.))

$(TR $(TDNW $(D c[x])) $(TDNW $(D log n$(SUB c))) $(TD Provides
indexed access into the _container. The index type is
_container-defined. A container may define several index types (and
consequently overloaded indexing).))

$(TR  $(TDNW $(D c.moveAt(x))) $(TDNW $(D log n$(SUB c))) $(TD
Destructively reads and returns the value at position $(D x). The slot
is not removed from the _container; it is left initialized with $(D
T.init).))

$(TR  $(TDNW $(D c[x] = v)) $(TDNW $(D log n$(SUB c))) $(TD Sets
element at specified index into the _container.))

$(TR  $(TDNW $(D c[x] $(I op)= v)) $(TDNW $(D log n$(SUB c)))
$(TD Performs read-modify-write operation at specified index into the
_container.))

$(LEADINGROW Operations)

$(TR $(TDNW $(D e in c)) $(TDNW $(D log n$(SUB c))) $(TD
Returns nonzero if e is found in $(D c).))

$(TR  $(TDNW $(D c.lowerBound(v))) $(TDNW $(D log n$(SUB c))) $(TD
Returns a range of all elements strictly less than $(D v).))

$(TR  $(TDNW $(D c.upperBound(v))) $(TDNW $(D log n$(SUB c))) $(TD
Returns a range of all elements strictly greater than $(D v).))

$(TR  $(TDNW $(D c.equalRange(v))) $(TDNW $(D log n$(SUB c))) $(TD
Returns a range of all elements in $(D c) that are equal to $(D v).))

$(LEADINGROW Modifiers)

$(TR $(TDNW $(D c ~= x)) $(TDNW $(D n$(SUB c) + n$(SUB x)))
$(TD Appends $(D x) to $(D c). $(D x) may be a single element or an
input range type.))

$(TR  $(TDNW $(D c.clear())) $(TDNW $(D n$(SUB c))) $(TD Removes all
elements in $(D c).))

$(TR  $(TDNW $(D c.insert(x))) $(TDNW $(D n$(SUB x) * log n$(SUB c)))
$(TD Inserts $(D x) in $(D c) at a position (or positions) chosen by $(D c).))

$(TR  $(TDNW $(D c.stableInsert(x)))
$(TDNW $(D n$(SUB x) * log n$(SUB c))) $(TD Same as $(D c.insert(x)),
but is guaranteed to not invalidate any ranges.))

$(TR  $(TDNW $(D c.linearInsert(v))) $(TDNW $(D n$(SUB c))) $(TD Same
as $(D c.insert(v)) but relaxes complexity to linear.))

$(TR  $(TDNW $(D c.stableLinearInsert(v))) $(TDNW $(D n$(SUB c)))
$(TD Same as $(D c.stableInsert(v)) but relaxes complexity to linear.))

$(TR  $(TDNW $(D c.removeAny())) $(TDNW $(D log n$(SUB c)))
$(TD Removes some element from $(D c) and returns it.))

$(TR  $(TDNW $(D c.stableRemoveAny())) $(TDNW $(D log n$(SUB c)))
$(TD Same as $(D c.removeAny()), but is guaranteed to not invalidate any
iterators.))

$(TR  $(TDNW $(D c.insertFront(v))) $(TDNW $(D log n$(SUB c)))
$(TD Inserts $(D v) at the front of $(D c).))

$(TR  $(TDNW $(D c.stableInsertFront(v))) $(TDNW $(D log n$(SUB c)))
$(TD Same as $(D c.insertFront(v)), but guarantees no ranges will be
invalidated.))

$(TR  $(TDNW $(D c.insertBack(v))) $(TDNW $(D log n$(SUB c)))
$(TD Inserts $(D v) at the back of $(D c).))

$(TR  $(TDNW $(D c.stableInsertBack(v))) $(TDNW $(D log n$(SUB c)))
$(TD Same as $(D c.insertBack(v)), but guarantees no ranges will be
invalidated.))

$(TR  $(TDNW $(D c.removeFront())) $(TDNW $(D log n$(SUB c)))
$(TD Removes the element at the front of $(D c).))

$(TR  $(TDNW $(D c.stableRemoveFront())) $(TDNW $(D log n$(SUB c)))
$(TD Same as $(D c.removeFront()), but guarantees no ranges will be
invalidated.))

$(TR  $(TDNW $(D c.removeBack())) $(TDNW $(D log n$(SUB c)))
$(TD Removes the value at the back of $(D c).))

$(TR  $(TDNW $(D c.stableRemoveBack())) $(TDNW $(D log n$(SUB c)))
$(TD Same as $(D c.removeBack()), but guarantees no ranges will be
invalidated.))

$(TR  $(TDNW $(D c.remove(r))) $(TDNW $(D n$(SUB r) * log n$(SUB c)))
$(TD Removes range $(D r) from $(D c).))

$(TR  $(TDNW $(D c.stableRemove(r)))
$(TDNW $(D n$(SUB r) * log n$(SUB c)))
$(TD Same as $(D c.remove(r)), but guarantees iterators are not
invalidated.))

$(TR  $(TDNW $(D c.linearRemove(r))) $(TDNW $(D n$(SUB c)))
$(TD Removes range $(D r) from $(D c).))

$(TR  $(TDNW $(D c.stableLinearRemove(r))) $(TDNW $(D n$(SUB c)))
$(TD Same as $(D c.linearRemove(r)), but guarantees iterators are not
invalidated.))

$(TR  $(TDNW $(D c.removeKey(k))) $(TDNW $(D log n$(SUB c)))
$(TD Removes an element from $(D c) by using its key $(D k).
The key's type is defined by the _container.))

$(TR  $(TDNW $(D )) $(TDNW $(D )) $(TD ))

)
 */

module std.container;

public import std.container.array;
public import std.container.binaryheap;
public import std.container.dlist;
public import std.container.rbtree;
public import std.container.slist;

