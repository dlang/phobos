Ddoc

$(D_S rdmd,

$(P
$(B rdmd) is a program to compile, cache and execute D source code files or 
'pseudo shell scripts' (using the she-bang syntax with dmd v0.146 or above) 
on Linux and Windows systems.
)

$(P
It will cache the executable in the /tmp directory by default and will 
re-compile the executable if any of the source file, the compiler or $(B rdmd) 
itself is newer than the cached executable. It can optionally use gdmd if 
specified, but uses dmd by default.
)

<h2>Usage:</h2>

$(P
        $(B rdmd) [$(I D compiler arguments)] [$(I rdmd arguments)] $(I progfile).d [$(I program arguments)]
)

$(P
$(I rdmd arguments):
)

$(DL
	$(DT $(B --help))
			$(DD This message)
	$(DT $(B --force))
			$(DD Force re-compilation of source code
			[default = do not force])
	$(DT $(B --compiler)=($(B dmd)|$(B gdmd)))
			$(DD Specify compiler [default = $(B dmd)])
	$(DT $(B --tmpdir)=$(I tmp_dir_path))
			$(DD Specify directory to store cached program 
			and other temporaries [default = $(B /tmp)])
)

<h2>Notes:</h2>

	$(UL
        $(LI $(B dmd) or $(B gdmd) must be in the current user context $PATH)
        $(LI $(B rdmd) does not support execution of D source code via stdin)
        $(LI $(B rdmd) will only compile and execute files with a '.d' file
	 extension)
	$(LI $(B rdmd)'s functionality will probably get folded into dmd itself)
	)

$(P written by Dave Fladebo and Robert Mariottini)
)

Macros:
	TITLE=rdmd
	WIKI=rdmd

