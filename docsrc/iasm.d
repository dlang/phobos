Ddoc

$(SPEC_S D x86 Inline Assembler,

	<a href="http://www.digitalmars.com/gift/index.html" title="Gift Shop" target="_top">
	<img src="d5.gif" border=0 align=right alt="Some Assembly Required" width=284 height=186>
	</a>

	$(P D, being a systems programming language, provides an inline
	assembler.
	The inline assembler is standardized for D implementations across
	the same CPU family, for example, the Intel Pentium inline assembler
	for a Win32 D compiler will be syntax compatible with the inline
	assembler for Linux running on an Intel Pentium.
	)

	$(P Differing D implementations, however, are free to innovate upon
	the memory model, function call/return conventions, argument
	passing conventions, etc.
	)

	$(P This document describes the x86 implementation of the inline
	assembler.
	)

$(GRAMMAR
$(I AsmInstruction):
	$(I Identifier) $(B :) $(I AsmInstruction)
	$(B align) $(I IntegerExpression)
	$(B even)
	$(B naked)
	$(B db) $(I Operands)
	$(B ds) $(I Operands)
	$(B di) $(I Operands)
	$(B dl) $(I Operands)
	$(B df) $(I Operands)
	$(B dd) $(I Operands)
	$(B de) $(I Operands)
	$(I Opcode)
	$(I Opcode Operands)

$(I Operands)
	$(I Operand)
	$(I Operand) $(B ,) $(I Operands)
)

<h2>Labels</h2>

	$(P Assembler instructions can be labeled just like other statements.
	They can be the target of goto statements.
	For example:
	)

--------------
void *pc;
asm
{
    call L1		;
 L1:			;
    pop	EBX		;
    mov	pc[EBP],EBX	;	// pc now points to code at L1
}
--------------

<h2>align $(I IntegerExpression)</h2>

	$(P Causes the assembler to emit NOP instructions to align the next
	assembler instruction on an $(I IntegerExpression) boundary.
	$(I IntegerExpression) must evaluate to an integer that is
	a power of 2.
	)

	$(P Aligning the start of a loop body can sometimes have a dramatic
	effect on the execution speed.
	)

<h2>even</h2>

	$(P Causes the assembler to emit NOP instructions to align the next
	assembler instruction on an even boundary.
	)

<h2>naked</h2>

	$(P Causes the compiler to not generate the function prolog and epilog
	sequences. This means such is the responsibility of inline
	assembly programmer, and is normally used when the entire function
	is to be written in assembler.
	)

<h2>db, ds, di, dl, df, dd, de</h2>

	These pseudo ops are for inserting raw data directly into
	the code.
	$(B db) is for bytes,
	$(B ds) is for 16 bit words,
	$(B di) is for 32 bit words,
	$(B dl) is for 64 bit words,
	$(B df) is for 32 bit floats,
	$(B dd) is for 64 bit doubles,
	and $(B de) is for 80 bit extended reals.
	Each can have multiple operands.
	If an operand is a string literal, it is as if there were $(I length)
	operands, where $(I length) is the number of characters in the string.
	One character is used per operand.
	For example:

--------------
asm
{
    db 5,6,0x83;   // insert bytes 0x05, 0x06, and 0x83 into code
    ds 0x1234;     // insert bytes 0x34, 0x12
    di 0x1234;     // insert bytes 0x34, 0x12, 0x00, 0x00
    dl 0x1234;     // insert bytes 0x34, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    df 1.234;      // insert float 1.234
    dd 1.234;      // insert double 1.234
    de 1.234;      // insert real 1.234
    db "abc";      // insert bytes 0x61, 0x62, and 0x63
    ds "abc";      // insert bytes 0x61, 0x00, 0x62, 0x00, 0x63, 0x00
}
--------------

<h2>Opcodes</h2>

	A list of supported opcodes is at the end.
	<p>

	The following registers are supported. Register names
	are always in upper case.

	<dl><dl>
	<dt>$(B AL), $(B AH), $(B AX), $(B EAX)
	<dt>$(B BL), $(B BH), $(B BX), $(B EBX)
	<dt>$(B CL), $(B CH), $(B CX), $(B ECX)
	<dt>$(B DL), $(B DH), $(B DX), $(B EDX)
	<dt>$(B BP), $(B EBP)
	<dt>$(B SP), $(B ESP)
	<dt>$(B DI), $(B EDI)
	<dt>$(B SI), $(B ESI)
	<dt>$(B ES), $(B CS), $(B SS), $(B DS), $(B GS), $(B FS)
	<dt>$(B CR0), $(B CR2), $(B CR3), $(B CR4)
	<dt>$(B DR0), $(B DR1), $(B DR2), $(B DR3), $(B DR6), $(B DR7)
	<dt>$(B TR3), $(B TR4), $(B TR5), $(B TR6), $(B TR7)
	<dt>$(B ST)
	<dt>$(B ST(0)), $(B ST(1)), $(B ST(2)), $(B ST(3)),
	    $(B ST(4)), $(B ST(5)), $(B ST(6)), $(B ST(7))
	<dt>$(B MM0), $(B MM1), $(B MM2), $(B MM3),
	    $(B MM4), $(B MM5), $(B MM6), $(B MM7)
	<dt>$(B XMM0), $(B XMM1), $(B XMM2), $(B XMM3),
	    $(B XMM4), $(B XMM5), $(B XMM6), $(B XMM7)
	</dl></dl>

<h3>Special Cases</h3>

$(DL

	$(DT $(B lock), $(B rep), $(B repe), $(B repne),
	 $(B repnz), $(B repz))
	$(DD These prefix instructions do not appear in the same statement
	as the instructions they prefix; they appear in their own statement.
	For example:

--------------
asm
{
    rep   ;
    movsb ;
}
--------------
	)

	$(DT $(B pause))
	$(DD This opcode is not supported by the assembler, instead use

--------------
{
    rep  ;
    nop  ;
}
--------------

	which produces the same result.
	)

	$(DT $(B floating point ops))
	$(DD Use the two operand form of the instruction format;

--------------
fdiv ST(1);	// wrong
fmul ST;        // wrong
fdiv ST,ST(1);	// right
fmul ST,ST(0);	// right
--------------
	)
)

<h2>Operands</h2>

$(GRAMMAR
$(I Operand):
    $(I AsmExp)

$(I AsmExp):
    $(I AsmLogOrExp)
    $(I AsmLogOrExp) $(B ?) $(I AsmExp) $(B :) $(I AsmExp)

$(I AsmLogOrExp):
    $(I AsmLogAndExp)
    $(I AsmLogAndExp) $(B ||) $(I AsmLogAndExp)

$(I AsmLogAndExp):
    $(I AsmOrExp)
    $(I AsmOrExp) $(B &&) $(I AsmOrExp)

$(I AsmOrExp):
    $(I AsmXorExp)
    $(I AsmXorExp) $(B |) $(I AsmXorExp)

$(I AsmXorExp):
    $(I AsmAndExp)
    $(I AsmAndExp) $(B ^) $(I AsmAndExp)

$(I AsmAndExp):
    $(I AsmEqualExp)
    $(I AsmEqualExp) $(B &) $(I AsmEqualExp)

$(I AsmEqualExp):
    $(I AsmRelExp)
    $(I AsmRelExp) $(B ==) $(I AsmRelExp)
    $(I AsmRelExp) $(B !=) $(I AsmRelExp)

$(I AsmRelExp):
    $(I AsmShiftExp)
    $(I AsmShiftExp) $(B &lt;) $(I AsmShiftExp)
    $(I AsmShiftExp) $(B &lt;=) $(I AsmShiftExp)
    $(I AsmShiftExp) $(B &gt;) $(I AsmShiftExp)
    $(I AsmShiftExp) $(B &gt;=) $(I AsmShiftExp)

$(I AsmShiftExp):
    $(I AsmAddExp)
    $(I AsmAddExp) $(B &lt;&lt;) $(I AsmAddExp)
    $(I AsmAddExp) $(B &gt;&gt;) $(I AsmAddExp)
    $(I AsmAddExp) $(B &gt;&gt;&gt;) $(I AsmAddExp)

$(I AsmAddExp):
    $(I AsmMulExp)
    $(I AsmMulExp) $(B +) $(I AsmMulExp)
    $(I AsmMulExp) $(B -) $(I AsmMulExp)

$(I AsmMulExp):
    $(I AsmBrExp)
    $(I AsmBrExp) $(B *) $(I AsmBrExp)
    $(I AsmBrExp) $(B /) $(I AsmBrExp)
    $(I AsmBrExp) $(B %) $(I AsmBrExp)

$(I AsmBrExp):
    $(I AsmUnaExp)
    $(I AsmBrExp) $(B [) $(I AsmExp) $(B ])

$(I AsmUnaExp):
    $(I AsmTypePrefix) $(I AsmExp)
    $(B offset) $(I AsmExp)
    $(B seg) $(I AsmExp)
    $(B +) $(I AsmUnaExp)
    $(B -) $(I AsmUnaExp)
    $(B !) $(I AsmUnaExp)
    $(B ~) $(I AsmUnaExp)
    $(I AsmPrimaryExp)

$(I AsmPrimaryExp)
    $(I IntegerConstant)
    $(I FloatConstant)
    $(B __LOCAL_SIZE)
    $(B $)
    $(I Register)
    $(I DotIdentifier)

$(I DotIdentifier)
    $(I Identifier)
    $(I Identifier) $(B .) $(I DotIdentifier)
)

	The operand syntax more or less follows the Intel CPU documentation
	conventions.
	In particular, the convention is that for two operand instructions
	the source is the right operand and the destination is the left
	operand.
	The syntax differs from that of Intel's in order to be compatible
	with the D language tokenizer and to simplify parsing.

<h3>Operand Types</h3>

$(GRAMMAR
$(I AsmTypePrefix):
	$(B near ptr)
	$(B far ptr)
	$(B byte ptr)
	$(B short ptr)
	$(B int ptr)
	$(B word ptr)
	$(B dword ptr)
	$(B float ptr)
	$(B double ptr)
	$(B real ptr)
)

	In cases where the operand size is ambiguous, as in:

--------------
add	[EAX],3		;
--------------

	it can be disambiguated by using an $(I AsmTypePrefix):

--------------
add	byte ptr [EAX],3	;
add	int ptr [EAX],7		;
--------------

<h3>Struct/Union/Class Member Offsets</h3>

	To access members of an aggregate, given a pointer to the aggregate
	is in a register, use the qualified name of the member:

--------------
struct Foo { int a,b,c; }
int bar(Foo *f)
{
    asm
    {	mov	EBX,f		;
	mov	EAX,Foo.b[EBX]	;
    }
}
--------------

<h3>Stack Variables</h3>

	$(P Stack variables (variables local to a function and allocated
	on the stack) are accessed via the name of the variable indexed
	by EBP:
	)

---
int foo(int x)
{
    asm
    {
	mov EAX,x[EBP]	;  // loads value of parameter x into EAX
	mov EAX,x	;  // does the same thing
    }
}
---

	$(P If the [EBP] is omitted, it is assumed for local variables.
	If $(B naked) is used, this no longer holds.
	)

<h3>Special Symbols</h3>

	<dl><dl>

	<dt>$(B &#36;&#36;)
	<dd>Represents the program counter of the start of the next
	instruction. So,

--------------
jmp	$  ;
--------------

	branches to the instruction following the jmp instruction.
	<p>

	<dt>$(B __LOCAL_SIZE)
	<dd>This gets replaced by the number of local bytes in the local
	stack frame. It is most handy when the $(B naked) is invoked
	and a custom stack frame is programmed.

	</dl></dl>

<h2>Opcodes Supported</h2>

	$(TABLE1
	<tr>
  	<td>aaa</td>
  	<td>aad</td>
  	<td>aam</td>
  	<td>aas</td>
  	<td>adc</td>
	</tr><tr>
  	<td>add</td>
  	<td>addpd</td>
  	<td>addps</td>
  	<td>addsd</td>
  	<td>addss</td>
	</tr><tr>
  	<td>and</td>
  	<td>andnpd</td>
  	<td>andnps</td>
  	<td>andpd</td>
  	<td>andps</td>
	</tr><tr>
  	<td>arpl</td>
  	<td>bound</td>
  	<td>bsf</td>
  	<td>bsr</td>
  	<td>bswap</td>
	</tr><tr>
  	<td>bt</td>
  	<td>btc</td>
  	<td>btr</td>
  	<td>bts</td>
  	<td>call</td>
	</tr><tr>
  	<td>cbw</td>
  	<td>cdq</td>
  	<td>clc</td>
  	<td>cld</td>
	<td>clflush</td>
	</tr><tr>
  	<td>cli</td>
  	<td>clts</td>
  	<td>cmc</td>
  	<td>cmova</td>
  	<td>cmovae</td>
	</tr><tr>
  	<td>cmovb</td>
  	<td>cmovbe</td>
  	<td>cmovc</td>
  	<td>cmove</td>
  	<td>cmovg</td>
	</tr><tr>
  	<td>cmovge</td>
  	<td>cmovl</td>
  	<td>cmovle</td>
  	<td>cmovna</td>
  	<td>cmovnae</td>
	</tr><tr>
  	<td>cmovnb</td>
  	<td>cmovnbe</td>
  	<td>cmovnc</td>
  	<td>cmovne</td>
  	<td>cmovng</td>
	</tr><tr>
  	<td>cmovnge</td>
  	<td>cmovnl</td>
  	<td>cmovnle</td>
  	<td>cmovno</td>
  	<td>cmovnp</td>
	</tr><tr>
  	<td>cmovns</td>
  	<td>cmovnz</td>
  	<td>cmovo</td>
  	<td>cmovp</td>
  	<td>cmovpe</td>
	</tr><tr>
  	<td>cmovpo</td>
  	<td>cmovs</td>
  	<td>cmovz</td>
  	<td>cmp</td>
  	<td>cmppd</td>
	</tr><tr>
  	<td>cmpps</td>
  	<td>cmps</td>
  	<td>cmpsb</td>
  	<td>cmpsd</td>
  	<td>cmpss</td>
	</tr><tr>
  	<td>cmpsw</td>
  	<td>cmpxch8b</td>
  	<td>cmpxchg</td>
  	<td>comisd</td>
  	<td>comiss</td>
	</tr><tr>
  	<td>cpuid</td>
	<td>cvtdq2pd</td>
	<td>cvtdq2ps</td>
	<td>cvtpd2dq</td>
	<td>cvtpd2pi</td>
	</tr><tr>
	<td>cvtpd2ps</td>
	<td>cvtpi2pd</td>
	<td>cvtpi2ps</td>
	<td>cvtps2dq</td>
	<td>cvtps2pd</td>
	</tr><tr>
	<td>cvtps2pi</td>
	<td>cvtsd2si</td>
	<td>cvtsd2ss</td>
	<td>cvtsi2sd</td>
	<td>cvtsi2ss</td>
	</tr><tr>
	<td>cvtss2sd</td>
	<td>cvtss2si</td>
	<td>cvttpd2dq</td>
	<td>cvttpd2pi</td>
	<td>cvttps2dq</td>
	</tr><tr>
	<td>cvttps2pi</td>
	<td>cvttsd2si</td>
	<td>cvttss2si</td>
  	<td>cwd</td>
  	<td>cwde</td>
	</tr><tr>
  	<td>da</td>
  	<td>daa</td>
  	<td>das</td>
  	<td>db</td>
  	<td>dd</td>
	</tr><tr>
  	<td>de</td>
  	<td>dec</td>
  	<td>df</td>
  	<td>di</td>
  	<td>div</td>
	</tr><tr>
	<td>divpd</td>
	<td>divps</td>
	<td>divsd</td>
	<td>divss</td>
  	<td>dl</td>
	</tr><tr>
  	<td>dq</td>
  	<td>ds</td>
  	<td>dt</td>
  	<td>dw</td>
	<td>emms</td>
	</tr><tr>
  	<td>enter</td>
  	<td>f2xm1</td>
  	<td>fabs</td>
  	<td>fadd</td>
  	<td>faddp</td>
	</tr><tr>
  	<td>fbld</td>
  	<td>fbstp</td>
  	<td>fchs</td>
  	<td>fclex</td>
  	<td>fcmovb</td>
	</tr><tr>
  	<td>fcmovbe</td>
  	<td>fcmove</td>
  	<td>fcmovnb</td>
  	<td>fcmovnbe</td>
  	<td>fcmovne</td>
	</tr><tr>
  	<td>fcmovnu</td>
  	<td>fcmovu</td>
  	<td>fcom</td>
  	<td>fcomi</td>
  	<td>fcomip</td>
	</tr><tr>
  	<td>fcomp</td>
  	<td>fcompp</td>
  	<td>fcos</td>
  	<td>fdecstp</td>
  	<td>fdisi</td>
	</tr><tr>
  	<td>fdiv</td>
  	<td>fdivp</td>
  	<td>fdivr</td>
  	<td>fdivrp</td>
  	<td>feni</td>
	</tr><tr>
  	<td>ffree</td>
  	<td>fiadd</td>
  	<td>ficom</td>
  	<td>ficomp</td>
  	<td>fidiv</td>
	</tr><tr>
  	<td>fidivr</td>
  	<td>fild</td>
  	<td>fimul</td>
  	<td>fincstp</td>
  	<td>finit</td>
	</tr><tr>
  	<td>fist</td>
  	<td>fistp</td>
  	<td>fisub</td>
  	<td>fisubr</td>
  	<td>fld</td>
	</tr><tr>
  	<td>fld1</td>
  	<td>fldcw</td>
  	<td>fldenv</td>
  	<td>fldl2e</td>
  	<td>fldl2t</td>
	</tr><tr>
  	<td>fldlg2</td>
  	<td>fldln2</td>
  	<td>fldpi</td>
  	<td>fldz</td>
  	<td>fmul</td>
	</tr><tr>
  	<td>fmulp</td>
  	<td>fnclex</td>
  	<td>fndisi</td>
  	<td>fneni</td>
  	<td>fninit</td>
	</tr><tr>
  	<td>fnop</td>
  	<td>fnsave</td>
  	<td>fnstcw</td>
  	<td>fnstenv</td>
  	<td>fnstsw</td>
	</tr><tr>
  	<td>fpatan</td>
  	<td>fprem</td>
  	<td>fprem1</td>
  	<td>fptan</td>
  	<td>frndint</td>
	</tr><tr>
  	<td>frstor</td>
  	<td>fsave</td>
  	<td>fscale</td>
  	<td>fsetpm</td>
  	<td>fsin</td>
	</tr><tr>
  	<td>fsincos</td>
  	<td>fsqrt</td>
  	<td>fst</td>
  	<td>fstcw</td>
  	<td>fstenv</td>
	</tr><tr>
  	<td>fstp</td>
  	<td>fstsw</td>
  	<td>fsub</td>
  	<td>fsubp</td>
  	<td>fsubr</td>
	</tr><tr>
  	<td>fsubrp</td>
  	<td>ftst</td>
  	<td>fucom</td>
  	<td>fucomi</td>
  	<td>fucomip</td>
	</tr><tr>
  	<td>fucomp</td>
  	<td>fucompp</td>
  	<td>fwait</td>
  	<td>fxam</td>
  	<td>fxch</td>
	</tr><tr>
	<td>fxrstor</td>
	<td>fxsave</td>
  	<td>fxtract</td>
  	<td>fyl2x</td>
  	<td>fyl2xp1</td>
	</tr><tr>
  	<td>hlt</td>
  	<td>idiv</td>
  	<td>imul</td>
  	<td>in</td>
  	<td>inc</td>
	</tr><tr>
  	<td>ins</td>
  	<td>insb</td>
  	<td>insd</td>
  	<td>insw</td>
  	<td>int</td>
	</tr><tr>
  	<td>into</td>
  	<td>invd</td>
  	<td>invlpg</td>
  	<td>iret</td>
  	<td>iretd</td>
	</tr><tr>
  	<td>ja</td>
  	<td>jae</td>
  	<td>jb</td>
  	<td>jbe</td>
  	<td>jc</td>
	</tr><tr>
  	<td>jcxz</td>
  	<td>je</td>
  	<td>jecxz</td>
  	<td>jg</td>
  	<td>jge</td>
	</tr><tr>
  	<td>jl</td>
  	<td>jle</td>
  	<td>jmp</td>
  	<td>jna</td>
  	<td>jnae</td>
	</tr><tr>
  	<td>jnb</td>
  	<td>jnbe</td>
  	<td>jnc</td>
  	<td>jne</td>
  	<td>jng</td>
	</tr><tr>
  	<td>jnge</td>
  	<td>jnl</td>
  	<td>jnle</td>
  	<td>jno</td>
  	<td>jnp</td>
	</tr><tr>
  	<td>jns</td>
  	<td>jnz</td>
  	<td>jo</td>
  	<td>jp</td>
  	<td>jpe</td>
	</tr><tr>
  	<td>jpo</td>
  	<td>js</td>
  	<td>jz</td>
  	<td>lahf</td>
  	<td>lar</td>
	</tr><tr>
	<td>ldmxcsr</td>
  	<td>lds</td>
  	<td>lea</td>
  	<td>leave</td>
  	<td>les</td>
	</tr><tr>
	<td>lfence</td>
  	<td>lfs</td>
  	<td>lgdt</td>
  	<td>lgs</td>
  	<td>lidt</td>
	</tr><tr>
  	<td>lldt</td>
  	<td>lmsw</td>
	<td>lock</td>
  	<td>lods</td>
  	<td>lodsb</td>
	</tr><tr>
  	<td>lodsd</td>
  	<td>lodsw</td>
  	<td>loop</td>
  	<td>loope</td>
  	<td>loopne</td>
	</tr><tr>
  	<td>loopnz</td>
  	<td>loopz</td>
  	<td>lsl</td>
  	<td>lss</td>
  	<td>ltr</td>
	</tr><tr>
	<td>maskmovdqu</td>
	<td>maskmovq</td>
	<td>maxpd</td>
	<td>maxps</td>
	<td>maxsd</td>
	</tr><tr>
	<td>maxss</td>
	<td>mfence</td>
	<td>minpd</td>
	<td>minps</td>
	<td>minsd</td>
	</tr><tr>
	<td>minss</td>
  	<td>mov</td>
	<td>movapd</td>
	<td>movaps</td>
  	<td>movd</td>
	</tr><tr>
	<td>movdq2q</td>
	<td>movdqa</td>
	<td>movdqu</td>
	<td>movhlps</td>
	<td>movhpd</td>
	</tr><tr>
	<td>movhps</td>
	<td>movlhps</td>
	<td>movlpd</td>
	<td>movlps</td>
	<td>movmskpd</td>
	</tr><tr>
	<td>movmskps</td>
	<td>movntdq</td>
	<td>movnti</td>
	<td>movntpd</td>
	<td>movntps</td>
	</tr><tr>
	<td>movntq</td>
  	<td>movq</td>
	<td>movq2dq</td>
  	<td>movs</td>
  	<td>movsb</td>
	</tr><tr>
  	<td>movsd</td>
	<td>movss</td>
  	<td>movsw</td>
  	<td>movsx</td>
	<td>movupd</td>
	</tr><tr>
	<td>movups</td>
  	<td>movzx</td>
  	<td>mul</td>
	<td>mulpd</td>
	<td>mulps</td>
	</tr><tr>
	<td>mulsd</td>
	<td>mulss</td>
  	<td>neg</td>
  	<td>nop</td>
  	<td>not</td>
	</tr><tr>
  	<td>or</td>
	<td>orpd</td>
	<td>orps</td>
  	<td>out</td>
  	<td>outs</td>
	</tr><tr>
  	<td>outsb</td>
  	<td>outsd</td>
  	<td>outsw</td>
	<td>packssdw</td>
	<td>packsswb</td>
	</tr><tr>
	<td>packuswb</td>
	<td>paddb</td>
	<td>paddd</td>
	<td>paddq</td>
	<td>paddsb</td>
	</tr><tr>
	<td>paddsw</td>
	<td>paddusb</td>
	<td>paddusw</td>
	<td>paddw</td>
	<td>pand</td>
	</tr><tr>
	<td>pandn</td>
	<td>pavgb</td>
	<td>pavgw</td>
	<td>pcmpeqb</td>
	<td>pcmpeqd</td>
	</tr><tr>
	<td>pcmpeqw</td>
	<td>pcmpgtb</td>
	<td>pcmpgtd</td>
	<td>pcmpgtw</td>
	<td>pextrw</td>
	</tr><tr>
	<td>pinsrw</td>
	<td>pmaddwd</td>
	<td>pmaxsw</td>
	<td>pmaxub</td>
	<td>pminsw</td>
	</tr><tr>
	<td>pminub</td>
	<td>pmovmskb</td>
	<td>pmulhuw</td>
	<td>pmulhw</td>
	<td>pmullw</td>
	</tr><tr>
	<td>pmuludq</td>
  	<td>pop</td>
  	<td>popa</td>
  	<td>popad</td>
  	<td>popf</td>
	</tr><tr>
  	<td>popfd</td>
	<td>por</td>
	<td>prefetchnta</td>
	<td>prefetcht0</td>
	<td>prefetcht1</td>
	</tr><tr>
	<td>prefetcht2</td>
	<td>psadbw</td>
	<td>pshufd</td>
	<td>pshufhw</td>
	<td>pshuflw</td>
	</tr><tr>
	<td>pshufw</td>
	<td>pslld</td>
	<td>pslldq</td>
	<td>psllq</td>
	<td>psllw</td>
	</tr><tr>
	<td>psrad</td>
	<td>psraw</td>
	<td>psrld</td>
	<td>psrldq</td>
	<td>psrlq</td>
	</tr><tr>
	<td>psrlw</td>
	<td>psubb</td>
	<td>psubd</td>
	<td>psubq</td>
	<td>psubsb</td>
	</tr><tr>
	<td>psubsw</td>
	<td>psubusb</td>
	<td>psubusw</td>
	<td>psubw</td>
	<td>punpckhbw</td>
	</tr><tr>
	<td>punpckhdq</td>
	<td>punpckhqdq</td>
	<td>punpckhwd</td>
	<td>punpcklbw</td>
	<td>punpckldq</td>
	</tr><tr>
	<td>punpcklqdq</td>
	<td>punpcklwd</td>
  	<td>push</td>
  	<td>pusha</td>
  	<td>pushad</td>
	</tr><tr>
  	<td>pushf</td>
  	<td>pushfd</td>
	<td>pxor</td>
  	<td>rcl</td>
	<td>rcpps</td>
	</tr><tr>
	<td>rcpss</td>
  	<td>rcr</td>
  	<td>rdmsr</td>
	<td>rdpmc</td>
  	<td>rdtsc</td>
	</tr><tr>
  	<td>rep</td>
  	<td>repe</td>
  	<td>repne</td>
  	<td>repnz</td>
  	<td>repz</td>
	</tr><tr>
  	<td>ret</td>
  	<td>retf</td>
  	<td>rol</td>
  	<td>ror</td>
  	<td>rsm</td>
	</tr><tr>
	<td>rsqrtps</td>
	<td>rsqrtss</td>
  	<td>sahf</td>
  	<td>sal</td>
  	<td>sar</td>
	</tr><tr>
  	<td>sbb</td>
  	<td>scas</td>
  	<td>scasb</td>
  	<td>scasd</td>
  	<td>scasw</td>
	</tr><tr>
  	<td>seta</td>
  	<td>setae</td>
  	<td>setb</td>
  	<td>setbe</td>
  	<td>setc</td>
	</tr><tr>
  	<td>sete</td>
  	<td>setg</td>
  	<td>setge</td>
  	<td>setl</td>
  	<td>setle</td>
	</tr><tr>
  	<td>setna</td>
  	<td>setnae</td>
  	<td>setnb</td>
  	<td>setnbe</td>
  	<td>setnc</td>
	</tr><tr>
  	<td>setne</td>
  	<td>setng</td>
  	<td>setnge</td>
  	<td>setnl</td>
  	<td>setnle</td>
	</tr><tr>
  	<td>setno</td>
  	<td>setnp</td>
  	<td>setns</td>
  	<td>setnz</td>
  	<td>seto</td>
	</tr><tr>
  	<td>setp</td>
  	<td>setpe</td>
  	<td>setpo</td>
  	<td>sets</td>
  	<td>setz</td>
	</tr><tr>
	<td>sfence</td>
  	<td>sgdt</td>
  	<td>shl</td>
  	<td>shld</td>
  	<td>shr</td>
	</tr><tr>
  	<td>shrd</td>
	<td>shufpd</td>
	<td>shufps</td>
  	<td>sidt</td>
  	<td>sldt</td>
	</tr><tr>
  	<td>smsw</td>
	<td>sqrtpd</td>
	<td>sqrtps</td>
	<td>sqrtsd</td>
	<td>sqrtss</td>
	</tr><tr>
  	<td>stc</td>
  	<td>std</td>
  	<td>sti</td>
	<td>stmxcsr</td>
  	<td>stos</td>
	</tr><tr>
  	<td>stosb</td>
  	<td>stosd</td>
  	<td>stosw</td>
  	<td>str</td>
  	<td>sub</td>
	</tr><tr>
	<td>subpd</td>
	<td>subps</td>
	<td>subsd</td>
	<td>subss</td>
	<td>sysenter</td>
	</tr><tr>
	<td>sysexit</td>
  	<td>test</td>
	<td>ucomisd</td>
	<td>ucomiss</td>
	<td>ud2</td>
	</tr><tr>
	<td>unpckhpd</td>
	<td>unpckhps</td>
	<td>unpcklpd</td>
	<td>unpcklps</td>
  	<td>verr</td>
	</tr><tr>
  	<td>verw</td>
  	<td>wait</td>
  	<td>wbinvd</td>
  	<td>wrmsr</td>
  	<td>xadd</td>
	</tr><tr>
  	<td>xchg</td>
  	<td>xlat</td>
  	<td>xlatb</td>
  	<td>xor</td>
	<td>xorpd</td>
	</tr><tr>
	<td>xorps</td>
	<td> </td>
	<td> </td>
	<td> </td>
	<td> </td>
	</tr>
	)

<h3>Pentium 4 (Prescott) Opcodes Supported</h3>

	$(TABLE1
	<tr>
	<td>addsubpd</td>
	<td>addsubps</td>
  	<td>fisttp</td>
	<td>haddpd</td>
	<td>haddps</td>
	</tr><tr>
	<td>hsubpd</td>
	<td>hsubps</td>
	<td>lddqu</td>
	<td>monitor</td>
	<td>movddup</td>
	</tr><tr>
	<td>movshdup</td>
	<td>movsldup</td>
	<td>mwait</td>
	<td> </td>
	<td> </td>

	</tr>
	)

<h3>AMD Opcodes Supported</h3>

	$(TABLE1
	<tr>
	<td>pavgusb</td>
	<td>pf2id</td>
	<td>pfacc</td>
	<td>pfadd</td>
	<td>pfcmpeq</td>
	</tr><tr>
	<td>pfcmpge</td>
	<td>pfcmpgt</td>
	<td>pfmax</td>
	<td>pfmin</td>
	<td>pfmul</td>
	</tr><tr>
	<td>pfnacc</td>
	<td>pfpnacc</td>
	<td>pfrcp</td>
	<td>pfrcpit1</td>
	<td>pfrcpit2</td>
	</tr><tr>
	<td>pfrsqit1</td>
	<td>pfrsqrt</td>
	<td>pfsub</td>
	<td>pfsubr</td>
	<td>pi2fd</td>
	</tr><tr>
	<td>pmulhrw</td>
	<td>pswapd</td>
	</tr>
	)

)

Macros:
	TITLE=Inline Assembler
	WIKI=IAsm

