Ddoc

$(D_S Exception Safe Programming,

Exception safe programming is programming so that if any piece of
code that might throw an exception does throw an exception, then
the state of the program is not corrupted and resources are not leaked.
Getting this right using traditional methods often results in complex,
unappealing and brittle code. As a result, exception safety often
is either buggy or simply ignored for
the sake of expediency.


<h3>Example</h3>

For example, if there's a Mutex m that must be acquired and held
for a few statements, then released:

---
void abc()
{
    Mutex m = new Mutex;
    lock(m);	// lock the mutex
    foo();	// do processing
    unlock(m);	// unlock the mutex
}
---

$(P If foo() throws an exception, then abc() exits via exception unwinding,
unlock(m) is never called and the Mutex is not released. This is a fatal
problem with this code.
)

$(P The RAII (Resource Acquisition Is Initialization) idiom
and the try-finally statement form the backbone of
the traditional approaches to writing exception safe programming.
)

$(P RAII is scoped destruction, and the example can be fixed by providing
a Lock class with a destructor that gets called upon the exit of the scope:
)

---
class Lock
{
    Mutex m;

    this(Mutex m)
    {
	this.m = m;
	lock(m);
    }

    ~this()
    {
	unlock(m);
    }
}

void abc()
{
    Mutex m = new Mutex;
    scope L = new Lock(m);
    foo();	// do processing
}
---

If abc() is exited normally or via an exception thrown from foo(), L gets
its destructor called and the mutex is unlocked.
The try-finally solution to the same problem looks like:

---
void abc()
{
    Mutex m = new Mutex;
    lock(m);	// lock the mutex
    try
    {
	foo();	// do processing
    }
    finally
    {
	unlock(m);	// unlock the mutex
    }
}
---

$(P Both solutions work, but both have drawbacks.
The RAII solution often requires
the creation of an extra dummy class, which is both a lot of lines of code to
write and a lot of clutter obscuring the control flow logic.
This is worthwhile to manage resources that must be cleaned up and that appear
more than once in a program, but it is clutter when it only needs to be
done once.
The try-finally
solution separates the unwinding code from the setup, and it can often be
a visually large separation. Closely related code should be grouped together.
)

$(P The $(LINK2 statement.html#ScopeGuardStatement, scope exit) statement is an easier
approach:
)

---
void abc()
{
    Mutex m = new Mutex;

    lock(m);	// lock the mutex
    scope(exit) unlock(m);	// unlock on leaving the scope

    foo();	// do processing
}
---

The $(D_KEYWORD scope)(exit) statement is executed at the closing curly
brace upon
normal execution, or when the scope is left due to an exception having
been thrown.
It places the unwinding code where it aesthetically belongs, next to the
creation of the state that needs unwinding. It's far less code to write
than either the RAII or try-finally solutions, and doesn't require the
creation of dummy classes.

<h3>Example</h3>

The next example is in a class of problems known as transaction processing:

---
Transaction abc()
{
    Foo f;
    Bar b;

    f = dofoo();
    b = dobar();

    return Transaction(f, b);
}
---

$(P Both dofoo() and dobar() must succeed, or the transaction has failed.
If the transaction failed, the data must be restored to the state
where neither dofoo() nor dobar() have happened. To support that,
dofoo() has an unwind operation, dofoo_undo(Foo f) which will roll back
the creation of a Foo.
)

$(P With the RAII approach:
)

---
class FooX
{
    Foo f;
    bool commit;

    this()
    {
	f = dofoo();
    }

    ~this()
    {
	if (!commit)
	    dofoo_undo(f);
    }
}

Transaction abc()
{
    scope f = new FooX();
    Bar b = dobar();
    f.commit = true;
    return Transaction(f.f, b);
}
---

With the try-finally approach:

---
Transaction abc()
{
    Foo f;
    Bar b;

    f = dofoo();
    try
    {
	b = dobar();
	return Transaction(f, b);
    }
    catch (Object o)
    {
	dofoo_undo(f);
	throw o;
    }
}
---

$(P These work too, but have the same problems.
The RAII approach involves the creation of dummy classes, and the obtuseness
of moving some of the logic out of the abc() function.
The try-finally approach is wordy even with this simple example; try
writing it if there are more than two components of the transaction that
must succeed. It scales poorly.
)

$(P The $(D_KEYWORD scope)(failure) statement solution looks like:
)

---
Transaction abc()
{
    Foo f;
    Bar b;

    f = dofoo();
    scope(failure) dofoo_undo(f);

    b = dobar();

    return Transaction(f, b);
}
---

The dofoo_undo(f) only is executed if the scope is exited via an
exception. The unwinding code is minimal and kept aesthetically where
it belongs. It scales up in a natural way to more complex transactions:


---
Transaction abc()
{
    Foo f;
    Bar b;
    Def d;

    f = dofoo();
    scope(failure) dofoo_undo(f);

    b = dobar();
    scope(failure) dobar_unwind(b);

    d = dodef();

    return Transaction(f, b, d);
}
---

<h3>Example</h3>

The next example involves temporarily changing the state of some object.
Suppose there's a class data member $(TT verbose), which controls the
emission of messages logging the activity of the class.
Inside one of the methods, $(TT verbose) needs to be turned off because
there's a loop that would otherwise cause a blizzard of messages to be output:

---
class Foo
{
    bool verbose;	// true means print messages, false means silence
    ...
    bar()
    {
	auto verbose_save = verbose;
	verbose = false;
	... lots of code ...
	verbose = verbose_save;
    }
}
---

There's a problem if $(TT Foo.bar()) exits via an exception - the verbose
flag state is not restored.
That's easily fixed with $(D_KEYWORD scope)(exit):

---
class Foo
{
    bool verbose;	// true means print messages, false means silence
    ...
    bar()
    {
	auto verbose_save = verbose;
	verbose = false;
	scope(exit) verbose = verbose_save;

	...lots of code...
    }
}
---

$(P It also neatly solves the problem if $(TT ...lots of code...) goes on at
some length, and in the future a maintenance programmer inserts a
return statement in it, not realizing that verbose must be reset upon
exit. The reset code is where it belongs conceptually, rather than where
it gets executed
(an analogous case is the continuation expression in a $(I ForStatement)).
It works whether the scope is exited by a return, break, goto, continue,
or exception.
)

$(P The RAII solution would be to try and capture the false state of verbose
as a resource, an abstraction that doesn't make much sense.
The try-finally solution requires arbitrarily large separation between
the conceptually linked set and reset code, besides requiring
the addition of an irrelevant scope.
)

<h3>Example</h3>

Here's another example of a multi-step transaction,
this time for an email program.
Sending an email consists of two operations:

$(OL
$(LI Perform the SMTP send operation.)
$(LI Copy the email to the "Sent" folder, which in POP is on the local 
disk, and in IMAP is also remote.)
)

$(P Messages should not appear in "Sent" that haven't been actually sent,
and sent messages must actually appear in "Sent".
)

$(P Operation (1) is not undoable because it's a well-known distributed 
computing issue. Operation (2) is undoable with some degree of 
reliability. So we break the job down into three steps:
)

$(OL
$(LI Copy the message to "Sent" with a changed title "[Sending] 
&lt;Subject&gt;". This operation ensures there's space in the client's IMAP 
account (or on the local disk), the rights are proper, the connection 
exists and works, etc.)

$(LI Send the message via SMTP.)

$(LI If sending fails, delete the message from "Sent". If the message 
succeeds,
change its title from "[Sending] &lt;Subject&gt;" to "&lt;Subject&gt;". 
Both of these operation have a high probability to succeed. If the 
folder is local, the probability of success is very high. If the folder 
is remote, probability is still vastly higher than that of step (1) 
because it doesn't involve an arbitrarily large data transfer.)

)

---
class Mailer
{
    void Send(Message msg)
    {
	{
	    char[] origTitle = msg.Title();
	    scope(exit) msg.SetTitle(origTitle);
	    msg.SetTitle("[Sending] " ~ origTitle);
	    Copy(msg, "Sent");
	}
	scope(success) SetTitle(msg.ID(), "Sent", msg.Title);
	scope(failure) Remove(msg.ID(), "Sent");
	SmtpSend(msg);	// do the least reliable part last
    }
}
---

This is a compelling solution to a complex problem.
Rewriting it with RAII would require two extra silly classes, 
MessageTitleSaver and MessageRemover.
Rewriting the example with try-finally would require nested try-finally
statements or use of an extra variable to track state evolution.

<h3>Example</h3>

Consider giving feedback to the user about a lengthy 
operation (mouse changes to an hourglass, window title is 
red/italicized, ...).
With $(D_KEYWORD scope)(exit) that can be easily done without 
needing to make an artificial resource out of whatever UI state element 
used for the cues:

--------------
void LongFunction()
{
    State save = UIElement.GetState();
    scope(exit) UIElement.SetState(save);
    ...lots of code...
}
--------------

Even more so, $(D_KEYWORD scope)(success) and $(D_KEYWORD scope)(failure)
can be used to give an indication if the operation succeeded or if
an error occurred:

---
void LongFunction()
{
    State save = UIElement.GetState();
    scope(success) UIElement.SetState(save);
    scope(failure) UIElement.SetState(Failed(save));
    ...lots of code...
}
---

<h2>When to use RAII, try-catch-finally, and Scope</h2>

RAII is for managing resources, which is different from managing state 
or transactions. try-catch is still needed, as scope doesn't catch 
exceptions. It's try-finally that becomes redundant.

<h2>Acknowledgements</h2>

$(P Andrei Alexandrescu argued about the usefulness of these constructs on the
Usenet and also defined
their semantics in terms of try/catch/finally in a series of posts
to comp.lang.c++.moderated under the title
$(LINK2 http://groups.google.com/group/comp.lang.c++.moderated/browse_frm/thread/60117e9c1cd1c510/b8cbe52786b0f506, A safer/better C++?)
starting Dec 6, 2005.
D implements the idea
with a slightly modified syntax following its creator's experiments with the
feature and useful
$(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/34277.html, suggestions)
from the D programmer community,
especially Dawid Ciezarkiewicz and Chris Miller.
)

$(P I am indebted to Scott Meyers for teaching
me about exception safe programming.
)

<h2>References:</h2>

$(OL

$(LI $(LINK2 http://www.cuj.com/documents/s=8000/cujcexp1812alexandr/alexandr.htm,
Generic&lt;Programming&gt;: Change the Way You Write Exception-Safe Code Forever)
by Andrei Alexandrescu and Petru Marginean

)

$(LI "Item 29: Strive for exception-safe code" in
$(LINK2 http://www.amazon.com/exec/obidos/ASIN/0321334876/classicempire,
 Effective C++ Third Edition), pg. 127 by Scott Meyers

)

)

)

Macros:
	TITLE=Exception Safety
	WIKI=ExceptionSafe

