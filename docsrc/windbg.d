Ddoc

$(D_S Debugging D on Windows,

$(P The Microsoft Windows debugger $(TT \dmd\bin\windbg.exe) can be used to
symbolically debug D programs, even though it is a C++ debugger.
Versions of $(TT windbg.exe) other than the one supplied may not work with D.
)

$(P To prepare a program for symbolic debugging, compile
with the $(B -g) switch:
)

$(CONSOLE
dmd myprogram -g
)

$(P To invoke the debugger on it:
)

$(CONSOLE
windbg myprogram args...
)

$(P
where $(TT args...) are the command line arguments to myprogram.exe.
)

$(P When the debugger comes up, entering the command in the command window:)

$(CONSOLE
g _Dmain
)

$(P will execute the program up until the entry into $(TT main()).
From thence, pressing the $(B F10) key will single step each line
of code.)

$(P Basic Commands:)

$(DL

$(DT F5)
$(DD Go until breakpoint, an exception is thrown, or the end of the program.)

$(DT F7)
$(DD Continue until cursor.)

$(DT F8)
$(DD Single step, stepping into function calls.)

$(DT F10)
$(DD Single step, stepping over function calls.)
)

$(P For more comprehensive information on $(B windbg), consult the
file $(TT \dmd\bin\windbg.hlp).
)

$(COMMENT
<h2>Sample Debug Session</h2>

$(P This is a walkthrough of a typical debugging session. Given the program:)

----------
import std.stdio;

class Foo
{
    int x;
}

int main()
{
    Foo p;
    bar(p);
}

void bar(Foo p)
{
    abc(p);
}

void abc(Foo p)
{
    p.x++;
}
---------

$(P It is compiled and run with the following commands:)

$(CONSOLE
C:\bug>dmd bug -g
\dm\bin\link bug,,,user32+kernel32/co/noi;

C:\bug>bug
Error: Access Violation

C:\bug>
)

$(P It's obviously got a bug, so fire up the debugger with:)

$(CONSOLE
C:\bug>windbg bug.exe
)

$(P and the debugger window comes up:)

<img src="foo.bmp">

$(P Advance to the beginning of $(TT main()) by entering $(TT g _Dmain):)

<img src="windbg2.gif">

$(P now were at the beginning of main(). The upper left black window shows
the console output so far, the middle window shows the current location
and next instruction (the $(TT xor)), The lower right window shows the
current location in the source code, highlighted in yellow.)

$(P In order to run until the exception happens, use the $(TT g) command:)

<img src="windbg3.gif">

$(P The $(TT First chance exception) says an exception was thrown. The
lower right window now shows the line on which the exception happened
highlighted in yellow.)

$(P Now click on the [Window] menu and Select [Calls]:)

<img src="windbg4.gif">

$(P and a window will appear showing the call stack:)

<img src="windbg6.gif">

$(P Clicking on the [Disassembly] command brings up
the Disassembly window where the instruction that faulted is highlighted
in yellow. Clicking on the [Registers] command brings up
the register window, where EAX holds the value 00000000.)

<img src="windbg7.gif">

$(P The trouble is clearly that $(TT p) is $(TT null). Fix it by allocating
an instance for $(TT p):)

----------
import std.stdio;

class Foo
{
    int x;
}

int main()
{
    Foo p = new Foo;   // the fix
    bar(p);
}

void bar(Foo p)
{
    abc(p);
}

void abc(Foo p)
{
    p.x++;
}
---------

$(P and it should now compile and run without error.)
)

)

Macros:
	TITLE=windbg Debugger
	WIKI=Windbg
	TT=$(TT $0)

