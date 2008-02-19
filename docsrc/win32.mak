# makefile to build html files for DMD

DMD=dmd

SRC= cpptod.d ctod.d pretod.d cppstrings.d cppcomplex.d cppdbc.d	\
	index.d overview.d lex.d module.d dnews.d declaration.d type.d	\
	property.d attribute.d pragma.d expression.d statement.d	\
	arrays.d struct.d class.d enum.d function.d			\
	operatoroverloading.d template.d mixin.d dbc.d version.d	\
	errors.d garbage.d memory.d float.d iasm.d interface.d		\
	portability.d html.d entity.d abi.d windows.d dll.d		\
	htomodule.d faq.d dstyle.d wc.d future.d changelog.d		\
	glossary.d acknowledgements.d dcompiler.d builtin.d		\
	interfaceToC.d comparison.d rationale.d ddoc.d code_coverage.d	\
	exception-safe.d rdmd.d templates-revisited.d warnings.d	\
	ascii-table.d windbg.d htod.d regular-expression.d		\
	lazy-evaluation.d lisp-java-d.d variadic-function-templates.d	\
	howto-promote.d tuple.d template-comparison.d template-mixin.d	\
	final-const-invariant.d const.d traits.d COM.d cpp_interface.d	\
	hijack.d const3.d features2.d

IMG=dmlogo.gif cpp1.gif d002.ico c1.gif d3.gif d4.gif d5.gif favicon.gif

TARGETS=cpptod.html ctod.html pretod.html cppstrings.html		\
	cppcomplex.html cppdbc.html index.html overview.html lex.html	\
	module.html dnews.html declaration.html type.html		\
	property.html attribute.html pragma.html expression.html	\
	statement.html arrays.html struct.html class.html enum.html	\
	function.html operatoroverloading.html template.html		\
	mixin.html dbc.html version.html errors.html garbage.html	\
	memory.html float.html iasm.html interface.html			\
	portability.html html.html entity.html abi.html windows.html	\
	dll.html htomodule.html faq.html dstyle.html wc.html		\
	future.html changelog.html glossary.html acknowledgements.html	\
	dcompiler.html builtin.html interfaceToC.html comparison.html	\
	rationale.html ddoc.html code_coverage.html			\
	exception-safe.html rdmd.html templates-revisited.html		\
	warnings.html ascii-table.html windbg.html htod.html		\
	regular-expression.html lazy-evaluation.html lisp-java-d.html	\
	variadic-function-templates.html howto-promote.html tuple.html	\
	template-comparison.html template-mixin.html			\
	final-const-invariant.html const.html traits.html COM.html	\
	cpp_interface.html hijack.html const3.html features2.html


target: $(TARGETS)

.d.html:
	$(DMD) -o- -c -D doc.ddoc $*.d

abi.html : doc.ddoc abi.d

acknowledgements.html : doc.ddoc acknowledgements.d

arrays.html : doc.ddoc arrays.d

ascii-table.html : doc.ddoc ascii-table.d

attribute.html : doc.ddoc attribute.d

builtin.html : doc.ddoc builtin.d

changelog.html : doc.ddoc changelog.d

class.html : doc.ddoc class.d

code_coverage.html : doc.ddoc code_coverage.d

COM.html : doc.ddoc COM.d

comparison.html : doc.ddoc comparison.d

const.html : doc.ddoc const.d

const3.html : doc.ddoc const3.d

cpp_interface.html : doc.ddoc cpp_interface.d

cppdbc.html : doc.ddoc cppdbc.d

cppcomplex.html : doc.ddoc cppcomplex.d

cppstrings.html : doc.ddoc cppstrings.d

cpptod.html : doc.ddoc cpptod.d

ctod.html : doc.ddoc ctod.d

dbc.html : doc.ddoc dbc.d

dcompiler.html : doc.ddoc dcompiler.d

ddoc.html : doc.ddoc ddoc.d

declaration.html : doc.ddoc declaration.d

dll.html : doc.ddoc dll.d

dnews.html : doc.ddoc dnews.d

dstyle.html : doc.ddoc dstyle.d

entity.html : doc.ddoc entity.d

enum.html : doc.ddoc enum.d

errors.html : doc.ddoc errors.d

exception-safe.html : doc.ddoc exception-safe.d

expression.html : doc.ddoc expression.d

faq.html : doc.ddoc faq.d

features2.html : doc.ddoc features2.d

final-const-invariant.html : doc.ddoc final-const-invariant.d

float.html : doc.ddoc float.d

function.html : doc.ddoc function.d

future.html : doc.ddoc future.d

garbage.html : doc.ddoc garbage.d

glossary.html : doc.ddoc glossary.d

hijack.html : doc.ddoc hijack.d

howto-promote.html : doc.ddoc howto-promote.d

html.html : doc.ddoc html.d

htod.html : doc.ddoc htod.d

htomodule.html : doc.ddoc htomodule.d

iasm.html : doc.ddoc iasm.d

interface.html : doc.ddoc interface.d

interfaceToC.html : doc.ddoc interfaceToC.d

index.html : doc.ddoc index.d

lazy-evaluation.html : doc.ddoc lazy-evaluation.d

lex.html : doc.ddoc lex.d

lisp-java-d.html : doc.ddoc lisp-java-d.d

memory.html : doc.ddoc memory.d

mixin.html : doc.ddoc mixin.d

module.html : doc.ddoc module.d

operatoroverloading.html : doc.ddoc operatoroverloading.d

overview.html : doc.ddoc overview.d

portability.html : doc.ddoc portability.d

pragma.html : doc.ddoc pragma.d

pretod.html : doc.ddoc pretod.d

property.html : doc.ddoc property.d

rationale.html : doc.ddoc rationale.d

rdmd.html : doc.ddoc rdmd.d

regular-expression.html : doc.ddoc regular-expression.d

statement.html : doc.ddoc statement.d

struct.html : doc.ddoc struct.d

template.html : doc.ddoc template.d

template-comparison.html : doc.ddoc template-comparison.d

template-mixin.html : doc.ddoc template-mixin.d

templates-revisited.html : doc.ddoc templates-revisited.d

traits.html : doc.ddoc traits.d

tuple.html : doc.ddoc tuple.d

type.html : doc.ddoc type.d

variadic-function-templates.html : doc.ddoc variadic-function-templates.d

version.html : doc.ddoc version.d

warnings.html : doc.ddoc warnings.d

wc.html : doc.ddoc wc.d

windbg.html : doc.ddoc windbg.d

windows.html : doc.ddoc windows.d

zip:
	del doc.zip
	zip32 doc win32.mak style.css doc.ddoc
	zip32 doc $(SRC) download.html
	zip32 doc $(IMG)

clean:
	del $(TARGETS)

