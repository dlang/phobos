
// openrj.d
// placed into Public Domain

module std.openrj;

import std.string;

alias char[][] [char[]] [] openrj_t;

class OpenrjException : Exception
{
    uint linnum;

    this(uint linnum, char[] msg)
    {
	this.linnum = linnum;
	super(std.string.format("OpenrjException line %s: %s", linnum, msg));
    }
}

openrj_t parse(char[] db)
{
    openrj_t rj;
    char[][] lines;
    char[][] [char[]] record;

    lines = std.string.splitlines(db);

    for (uint linnum = 0; linnum < lines.length; linnum++)
    {
	char[] line = lines[linnum];

	// Splice lines ending with backslash
	while (line.length && line[length - 1] == '\\')
	{
	    if (++linnum == lines.length)
		throw new OpenrjException(linnum, "no line after \\ line");
	    line = line[0 .. length - 1] ~ lines[linnum];
	}

	if (line[0 .. 2] == "%%")
	{
	    // Comment lines separate records
	    if (record)
		rj ~= record;
	    record = null;
	    line = null;
	    continue;
	}

	int colon = std.string.find(line, ':');
	if (colon == -1)
	    throw new OpenrjException(linnum, "'key : value' expected");

	char[] key = std.string.strip(line[0 .. colon]);
	char[] value = std.string.strip(line[colon + 1 .. length]);

	char[][] fields = record[key];
	fields ~= value;
	record[key] = fields;
    }
    if (record)
	rj ~= record;
    return rj;
}
