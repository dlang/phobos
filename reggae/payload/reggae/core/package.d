/**
 Public imports for only the core packages to enable reggae to be a D build system.
 Only support for D is imported, not even dub is supported.
 */

module reggae.core;

public import reggae.build;
public import reggae.reflect;
public import reggae.buildgen;
public import reggae.types;
public import reggae.config;
public import reggae.ctaa;
public import reggae.range;
public import reggae.backend.binary;
public import reggae.core.rules;
public import reggae.options;
