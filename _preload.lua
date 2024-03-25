
--
-- avoid loading twice this file (see unitybuild.lua)
--
premake.extensions.compilationunit = true


--
-- register our custom option
--
newoption {
	trigger = "unity-build",
	description = "(Optional) Enable experimental unity builds on projects that have opted into it."
}

newoption {
    trigger = "unity-log",
    description = "(Optional) Enable some extra debug logging for the unity builds.  This should"..
                  "only be used for debugging purposes when opting into unity builds for a project."
}

newoption {
    trigger = "unity-log-filter",
	value = "enabled",
    description = "(Optional) Only show the log messages from the unity build for the given project"..
				  "names.  Multiple project names may be given separated by commas (no blank spaces"..
				  "between project names).  This may also be the special value 'enabled' to only show"..
				  "the log messages for projects that have opted into unity builds."
}

--
-- Enable the compilation units for a given configuration
--
premake.api.register {
	name = "unitybuildenabled",
	scope = "config",
	kind = "boolean"
}

--
-- Set the preferred compilation unit file count for a project.
--
premake.api.register {
	name = "unitybuildcount",
	scope = "config",
	kind = "number"
}

--
-- Specify the path, relative to the current script or absolute, where the compilation
-- unit files will be stored. If not specified, the project's obj dir will be used.
--
premake.api.register {
	name = "unitybuilddir",
	scope = "project",
	kind = "path",
	tokens = true
}

--
-- Specifies a table of key/value pairs that will be added to each unity build file as
-- a set of macros when they are generated.  These can be used to work around potential
-- compilation issues due to multiple source files being compiled as one.  The macro
-- `OMNI_USING_UNITY_BUILD` will always be added to each unity build file with the value
-- `1`.  This macro name must not be included in this table.  This can be used for example
-- to work around the common problem of Windows' `min()` and `max()` macros by adding
-- the macro `NOMINMAX` and setting it to `1`.
--
premake.api.register {
    name = "unitybuilddefines",
    scope = "config",
    kind = "table"
}

-- Compilation unit extensions.
--
-- By default, either .c or .cpp extension are used for generated unity build files.
-- But you can override this extension per-language to let it handle objective-C or
-- any other.
--
-- Here's an example allowing to mix C or C++ files with objective-C:
-- 
-- filter {}
-- 	unitybuildextensions {
--		"C" = ".m",	-- compilation unit extension for C files is .m
--				-- (i.e. objective-C)
--		"C++" = ".mm"	-- compilation unit extension for C++ files is .mm
--				-- (i.e. objective-C++)
--	}
--
premake.api.register {
	name = "unitybuildextensions",
	scope = "config",
	kind = "table"
}

--
-- Tell if the original source files must be removed from the project (true), thus
-- keeping only the the generated compilation units, or if all files are kept (false).
--
-- Default is to keep the original source files.
--
premake.api.register {
	name = "unitybuildfilesonly",
	scope = "config",
	kind = "boolean"
}

--
-- Always load
--
return function () return true end
