// Written in the D programming language

/*
 *  Copyright (C) 2002-2008 by Digital Mars, www.digitalmars.com
 *  Written by Bartosz Milewski
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/**************************
 * The synchro module defines synchronization primitives.
 *
 * $(B CriticalSection) is an interprocess mutex
 * Macros:
 *      WIKI=Phobos/StdSynchro
 */

module std.synchro;

import std.c.stdio;

//debug=thread;

/* ================================ Windows ================================= */

version (Windows)
{

private import std.c.windows.windows;

class CriticalSection
{
public:
	this ()
	{
		InitializeCriticalSection (&_critSection);
	}
	~this ()
	{
		DeleteCriticalSection (&_critSection);
	}
private:
	void lock () 
	{
		EnterCriticalSection (&_critSection);
	}
	void unlock () 
	{ 
		LeaveCriticalSection (&_critSection);
	}
private:
	CRITICAL_SECTION	_critSection;
}

scope class Lock
{
public:
	this (CriticalSection critSect)
	{
		_critSect = critSect;
		_critSect.lock ();
	}
	~this ()
	{
		_critSect.unlock ();
	}
private:
	CriticalSection _critSect;
}

} // Windows

/* ================================ linux ================================= */

version (linux)
{

}

