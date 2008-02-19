# makefile to build html files for DMD

DMD=dmd

IMG=dmlogo.gif cpp1.gif d002.ico c1.gif d3.gif d4.gif d5.gif 
#favicon.gif

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

DOC_OUTPUT_DIR = ../web

TARGETS:=$(addprefix $(DOC_OUTPUT_DIR)/,$(TARGETS)) 

target: $(TARGETS) $(DOC_OUTPUT_DIR)/style.css \
        $(addprefix $(DOC_OUTPUT_DIR)/,$(IMG))

$(DOC_OUTPUT_DIR)/style.css : style.css
	cp $< $@

$(DOC_OUTPUT_DIR)/%.gif : %.gif
	cp $< $@

$(DOC_OUTPUT_DIR)/%.ico : %.ico
	cp $< $@

$(DOC_OUTPUT_DIR)/%.html : %.d doc.ddoc
	$(DMD) -c -o- -Df$@ doc.ddoc $<

zip:
	rm doc.zip
	zip32 doc win32.mak style.css doc.ddoc
	zip32 doc $(SRC) download.html
	zip32 doc $(IMG)

clean:
	rm -rf $(TARGETS) $(DOC_OUTPUT_DIR)/style.css

