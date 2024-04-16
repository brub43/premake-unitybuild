
--
-- always include _preload so that the module works even when not embedded.
--
if premake.extensions == nil or premake.extensions.compilationunit == nil then
	include ( "_preload.lua" )
end


--
-- define the extension
--
premake.extensions.compilationunit = {

	--
	-- these are private, do not touch
	--
	compilationunitname = "__unitybuild_file__",
	compilationunits = {}

}

-- Prints a single log message to `stdout`.  The message will only be output if the `--unity-log`
-- command line option was specified.  These messages can also be filtered to only show messages
-- from certain projects using the `--unity-log-filter` command line option.
--
-- @param msg: The log message to output.
-- @param prj: The project object that the message applies to.  This can be omitted or `nil` if
--             the message should not be filtered based on project settings.
--
-- @returns No return value.
function premake.extensions.compilationunit.debug_log(msg, prj)
	-- the unity builds log output is not enabled -> nothing to do => fail.
	if not _OPTIONS['unity-log'] then
		return
	end

	-- an optional project object was passed in and the log filtering was enabled => make sure
	--   this project was asked to emit log messages.
	if prj ~= nil and type(_OPTIONS['unity-log-filter']) == 'string' then
		if not (_OPTIONS['unity-log-filter']:find(prj['name']) or (prj.unitybuildenabled and _OPTIONS['unity-log-filter'] == 'enabled')) then
			return
		end
	end

	print("[unity] "..msg)
end

--
-- This method overrides premake.oven.bakeFiles method. We use it to add the compilation units
-- to the project, and then generate and fill them.
--
function premake.extensions.compilationunit.customBakeFiles(base, prj)

	-- calculate whether the unity builds should be enabled at all.  This is a combination of
	-- both whether the project has opted into unity builds and whether unity builds have been
	-- enabled on the command line with the `--unity-build` option.
	local unity_build_enabled = prj.unitybuildenabled and (_OPTIONS['unity-build'] ~= nil)
	local cu = premake.extensions.compilationunit
    local project_name = prj['name']

	-- do nothing for external projects
	if prj.external == true then
		return base(prj)
	end

	-- make sure this local var stays a boolean in all cases.
	if unity_build_enabled == nil then
		unity_build_enabled = false
	end

	local project = premake.project
	local unitybuildcount = {}


	-- add an entry in the compilation units file table for this project.  This will contain the
	-- unity build files list for each project that opts into it.  However, we only want to add
	-- it if unity builds are enabled otherwise adding files to the project later could be
	-- handled incorrectly.
	if unity_build_enabled then
		cu.compilationunits[project_name] = {}
	end

	-- first step: gather compilation units.
	-- this needs to take care of the case where the compilation units are generated in a folder from
	-- the project (we need to skip them in this case to avoid recursively adding them each time we
	-- run Premake.
	cu.debug_log("processing the unity build for the project '"..project_name.."'.", prj)
	cu.debug_log("unity builds are "..(unity_build_enabled and "ENABLED" or "DISABLED").." for the project '"..project_name.."'.", prj)
	for cfg in project.eachconfig(prj) do
        local config_name = cfg.shortname

		cu.debug_log("    processing the unity build for the config '"..cfg.shortname.."'.", prj)

		-- remove the previous compilation units
		cu.debug_log("    removing existing unity build files from the project.", prj)
		for i = #cfg.files, 1, -1 do
			-- cu.debug_log("        "..i..") checking the file '"..cfg.files[i].."'.", prj)
			if cu.isCompilationUnit(cfg, cfg.files[i]) then
				cu.debug_log("        "..i..") '"..cfg.files[i].."'", prj)
				table.remove(cfg.files, i)
			end
		end

		-- stop there when compilation units are disabled
		if unity_build_enabled == true then

			-- initialize the compilation unit structure for this config and project.  We'll make
			-- sure this table is indexed by both the project name and its config since the table
			-- is global to the workspace.  In theory the project name should be unique within the
			-- workspace.  Though note that we unfortunately need to index the config part of the
			-- table with the config object itself since we need to be able to recover that later.
			cu.compilationunits[project_name][cfg] = {}

			-- the indices of the files that must be included in the compilation units
			local sourceindexforcu = {}

			-- store the list of files for a later building of the actual compilation unit files
			cu.debug_log("    adding compilation units.", prj)
			for i = #cfg.files, 1, -1 do
				local filename = cfg.files[i]
				cu.debug_log("        checking the file '"..filename.."'.", prj)
				if cu.isIncludedInCompilationUnit(cfg, filename) == true then
					cu.debug_log("            adding the file '"..filename.."' under the config '"..tostring(cfg['shortname']).."' at index "..i, prj)
					table.insert(cu.compilationunits[project_name][cfg], filename)
					table.insert(sourceindexforcu, i)
				end
			end
			cu.debug_log("    done adding compilation units.", prj)

			-- remove the original source files from the project
			if cfg.unitybuildfilesonly then
				cu.debug_log("    removing the original source files from the project.", prj)
				table.foreachi(sourceindexforcu, function(i)
					cu.debug_log("        removing the file '"..cfg.files[i].."'", prj)
					table.remove(cfg.files, i)
				end)
			end

			-- store the compilation unit folder in the config
			if cfg._compilationUnitDir == nil then
				cfg._compilationUnitDir = cu.getCompilationUnitDir(cfg)
				cu.debug_log("    storing the CU dir '"..cfg._compilationUnitDir.."' in the config.", prj)
			end

			local count = 2

			-- the compilation unit count was not specified for this project => attempt to
			--   calculate a good count given how many eligible source files are present.
			--   We'll try to make sure there are at least 5 source files built in each
			--   unity build file, but we'll also cap it at 8 files.  If there are fewer
			--   than 5 source files in the project, this will simply be clamped to 1.
			if prj.unitybuildcount == nil then
				count = math.floor(#cu.compilationunits[project_name][cfg] / 5)
				count = math.min(count, 8) -- clamp it to 8 files as a maximum.  FIXME!! this should clamp to the CPU core count instead.
				count = math.max(count, 1) -- make sure we don't choose 0 files.

			-- the compilation unit count was specified for this project => use this count
			--   directly, but also clamp it to the total number of source files so that
			--   we don't end up with empty unity build files.
			else
				count = math.min(#cu.compilationunits[project_name][cfg], prj.unitybuildcount)
			end

			unitybuildcount[cfg['shortname']] = count
			cu.debug_log("    adding "..count.." unity build files to the project.", prj)
			for i = 1, count do
				cu.debug_log("        "..i..") '"..path.join(cfg._compilationUnitDir, cu.getCompilationUnitName(cfg, i)).."'", prj)
				table.insert(cfg.files, path.join(cfg._compilationUnitDir, cu.getCompilationUnitName(cfg, i)))
			end

		end

	end

	-- we removed any potential previous compilation units, early out if compilation units are not enabled
	if unity_build_enabled ~= true then
		cu.debug_log("unity builds are not enabled.  Skipping further setup for '"..prj['name'].."'.", prj)
		return base(prj)
	end

	-- report that this project is building with a unity build.  Note that this will only print
	-- for projects that have opted into unity builds _and_ the `--unity-build` command line
	-- option was also used.
	print("Unity build is enabled for the project '"..prj.name.."'.")

	-- second step: loop through the configs and generate the compilation units
	cu.debug_log("    generating unity build files for the project '"..prj['name'].."':", prj)
	for config, files in pairs(cu.compilationunits[project_name]) do
		cu.debug_log("        generating unity build files for the config '"..config['shortname'].."' {unitybuildcount['"..config['shortname'].."'] = "..unitybuildcount[config['shortname']].."}", prj)
		-- create the units
		local units = {}
		cu.debug_log("            building the unity build file lists:", prj)
		for i = 1, unitybuildcount[config['shortname']] do
			local content = "// use this symbol to conditionally include or exclude code that works fine when building a source\n"..
							"// file directly, but causes problems when building under a unity build.\n"..
							"#define OMNI_USING_UNITY_BUILD 1\n\n"

			-- add in any custom macros specified by this project.  Note that the '#' operator is
			-- broken on this particular table since values are added dynamically instead of at
			-- definition time so we unfortunately can't easily avoid adding the comment and
			-- newline if a project intentionally adds an empty table.
			if config.unitybuilddefines ~= nil and type(config.unitybuilddefines) == "table" then
				content = content.."// additional macros specified for this project's unity builds using `unitybuilddefines {}`:\n"

				for k, v in pairs(config.unitybuilddefines) do
					cu.debug_log("            adding the custom macro '"..k.."' set to '"..v.."'.")
					content = content.."#define "..k.." "..v.."\n"
				end

				-- add one last empty line before the includes.
				content = content.."\n"
			end

			-- add pch if needed
			if config.pchheader ~= nil then
				content = content .. "#include \"" .. config.pchheader .. "\"\n\n"
			end

			-- add the unit
			cu.debug_log("                "..i..") adding the file '"..path.join(config._compilationUnitDir, cu.getCompilationUnitName(config, i)).."'.", prj)
			table.insert(units, {
				filename = path.join(config._compilationUnitDir, cu.getCompilationUnitName(config, i)),
				content = content
			})
		end

		-- add files in the cpp unit
		local index = 1
		cu.debug_log("            generating the content for the unity build files:", prj)
		for _, filename in ipairs(files) do
			-- compute the relative path of the original file, to add the #include statement
			-- in the compilation unit
			local relativefilename = path.getrelative(path.getdirectory(units[index].filename), path.getdirectory(filename))
			relativefilename = path.join(relativefilename, path.getname(filename))
			units[index].content = units[index].content .. "#include \"" .. relativefilename .. "\"\n"
			cu.debug_log("                ".._..") added '"..relativefilename.."' at index "..index..".", prj)
			index = (index % unitybuildcount[config['shortname']]) + 1
		end

		-- write units
		cu.debug_log("            writing the unity build files to disk:", prj)
		for _, unit in ipairs(units) do
			-- get the content of the file, if it already exists
			cu.debug_log("                ".._..") opening the file '"..unit.filename.."' to read its contents.", prj)
			local file = io.open(unit.filename, "r")
			local content = ""
			if file ~= nil then
				content = file:read("*all")
				file:close()
			end

			-- overwrite only if the content changed
			if content ~= unit.content then
				cu.debug_log("                    writing the new contents to '"..unit.filename.."'.", prj)
				file = assert(io.open(unit.filename, "w"))
				file:write(unit.content)
				file:close()
			else
				cu.debug_log("                    skipping writing to the file '"..unit.filename.."' since it hasn't changed.", prj)
			end
		end
		cu.debug_log("        done generating unity build files for the config '"..config['shortname'].."'.", prj)
	end

	cu.debug_log("done processing the project '"..prj['name'].."'!", prj)
	return base(prj)
end


--
-- This method overrides premake.fileconfig.addconfig and adds a file configuration object
-- for each file, on each configuration. We use it to disable compilation of non-compilation
-- units files.
--
function premake.extensions.compilationunit.customAddFileConfig(base, fcfg, cfg)

	-- get the addon
	local cu = premake.extensions.compilationunit
	local project_name = cfg.project.name

	-- call the base method to add the file config
	base(fcfg, cfg)

	-- do nothing else if the compilation units are not enabled for this project
	if cfg.unitybuildenabled == nil or cu.compilationunits[project_name][cfg] == nil then
		return
	end

	-- get file name and config
	local filename = fcfg.abspath
	local config = premake.fileconfig.getconfig(fcfg, cfg)

	-- if the compilation units were explicitely disabled for this file, remove it
	-- from the compilation units and stop here
	if config.unitybuildenabled == false then
		local i = table.indexof(cu.compilationunits[project_name][cfg], filename)
		if i ~= nil then
			table.remove(cu.compilationunits[project_name][cfg], i)
		end
		return
	end

	-- if a file will be included in the compilation units, disable it
	if cu.isIncludedInCompilationUnit(cfg, filename) == true and cu.isCompilationUnit(cfg, filename) == false then
		cu.debug_log("    excluding the file '"..filename.."' from the configuration '"..cfg['shortname'].."'.")
		config.flags.ExcludeFromBuild = true
	end

end


--
-- Checks if a file should be included in the compulation units.
--
-- @param cfg
--		The active configuration
-- @param filename
--		The filename
-- @return
--		true if the file should be included in compilation units, false otherwise
--
function premake.extensions.compilationunit.isIncludedInCompilationUnit(cfg, filename)

	-- only handle source files
	if path.iscfile(filename) == false and path.iscppfile(filename) == false then
		return false
	end

	local cu = premake.extensions.compilationunit

	-- ignore PCH files
	if cu.isPCHSource(cfg, filename) == true then
		return false
	end

	-- it's ok !
	return true
end


--
-- Get the compilation unit output directory
--
-- @param cfg
--		The input configuration
--
function premake.extensions.compilationunit.getCompilationUnitDir(cfg)

	-- in this order:
	--	- check if unitybuilddir is used
	--	- if not, if we have an objdir set, use it
	--	- if not, re-create the obj dir like the default Premake one.

	local dir = ""
	if cfg.unitybuilddir then
		dir = cfg.unitybuilddir
	else
		if cfg.objdir then
			return cfg.objdir
		else
			dir = path.join(cfg.project.location, "obj")
		end
	end

	if cfg.platform then
		dir = path.join(dir, cfg.platform)
	end
	dir = path.join(dir, cfg.buildcfg)
	dir = path.join(dir, cfg.project.name)
	return path.getabsolute(dir)
end


--
-- Get the name of a compilation unit
--
-- @param cfg
--		The configuration for which we want the compilation unit's filename
-- @param index
--		The index of the compilation unit
-- @return
--		The name of the file.
--
function premake.extensions.compilationunit.getCompilationUnitName(cfg, index, shortName)

	local language = cfg.language
	local extension = nil

	if cfg.unitybuildextensions ~= nil then
		extension = cfg.unitybuildextensions[language]
	end

	if extension == nil then
		extension = iif(language == "C", ".c", ".cpp")
	end

	return premake.extensions.compilationunit.compilationunitname .. cfg.shortname .. "_" .. index .. extension
end


--
-- Checks if an absolute filename is a compilation unit.
--
-- @param cfg
--		The current configuration
-- @param absfilename
--		The absolute filename of the file to check
-- @return
-- 		true if the file is a compilation unit, false otherwise
--
function premake.extensions.compilationunit.isCompilationUnit(cfg, absfilename)
	return path.getname(absfilename):startswith(premake.extensions.compilationunit.compilationunitname)
end


--
-- Checks if a file is the PCH source.
--
-- @param cfg
--		The current configuration
-- @param absfilename
--		The absolute filename of the file to check
-- @return
-- 		true if the file is the PCH source, false otherwise
--
function premake.extensions.compilationunit.isPCHSource(cfg, absfilename)
	return cfg.pchsource ~= nil and cfg.pchsource:lower() == absfilename:lower()
end


--
-- If the compilationunit option was used, activate the addon
--
if _OPTIONS["unity-build"] ~= nil then

	local cu = premake.extensions.compilationunit

	-- setup the overrides
	premake.override(premake.oven, "bakeFiles", cu.customBakeFiles)
	premake.override(premake.fileconfig, "addconfig", cu.customAddFileConfig)

else

	-- still need this to avoid including compilation units of a previous build
	premake.override(premake.oven, "bakeFiles", premake.extensions.compilationunit.customBakeFiles)

end
