;_ minit.asm
; Copyright (C) 2001 by Digital Mars
; All rights reserved
; www.digitalmars.com

; Converts array of ModuleInfo pointers to a D dynamic array of them,
; so they can be accessed via D.

include macros.asm

ifdef _WIN32
  DATAGRP      EQU     FLAT
else
  DATAGRP      EQU     DGROUP
endif

public __nullext
__nullext	equ 0

	extrn	__moduleinfo_array:near

; These segments bracket FM, which contains the list of ModuleInfo pointers
FMB     segment dword use32 public 'DATA'
FMB     ends
FM      segment dword use32 public 'DATA'
FM      ends
FME     segment dword use32 public 'DATA'
FME     ends

; This leaves room in the _fatexit() list for _moduleDtor()
XOB     segment dword use32 public 'BSS'
XOB     ends
XO      segment dword use32 public 'BSS'
	dd	?
XO      ends
XOE     segment dword use32 public 'BSS'
XOE     ends

DGROUP         group   FMB,FM,FME

	begcode minit

	public	__minit
__minit	proc	near
	mov	EDX,offset DATAGRP:FMB
	mov	EAX,offset DATAGRP:FME
	mov	dword ptr __moduleinfo_array+4,EDX
	sub	EAX,EDX			; size in bytes of FM segment
	shr	EAX,2			; convert to array length
	mov	dword ptr __moduleinfo_array,EAX
	ret
__minit endp

	endcode minit

	end
