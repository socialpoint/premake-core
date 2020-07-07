--
-- xcode_common.lua
-- Functions to generate the different sections of an Xcode project.
-- Copyright (c) 2009-2015 Jason Perkins and the Premake project
--

	local p = premake
	local xcode = p.modules.xcode
	local tree  = p.tree
	local workspace = p.workspace
	local project = p.project
	local config = p.config
	local fileconfig = p.fileconfig

--
-- Return the Xcode build category for a given file, based on the file extension.
--
-- @param node
--    The node to identify.
-- @returns
--    An Xcode build category, one of "Sources", "Resources", "Frameworks", or nil.
--

	function xcode.getbuildcategory(node)
		local categories = {
			[".a"] = "Frameworks",
			[".c"] = "Sources",
			[".cc"] = "Sources",
			[".cpp"] = "Sources",
			[".cxx"] = "Sources",
			[".dylib"] = "Frameworks",
			[".framework"] = "Frameworks",
			[".m"] = "Sources",
			[".mm"] = "Sources",
			[".strings"] = "Resources",
			[".nib"] = "Resources",
			[".xib"] = "Resources",
			[".storyboard"] = "Resources",
			[".icns"] = "Resources",
			[".s"] = "Sources",
			[".S"] = "Sources",
			[".swift"] = "Sources",
		}
		if node.isResource then
			return "Resources"
		end
		return categories[path.getextension(node.name)]
	end

	function xcode.isItemResource(project, node)

		local res;

		if project and project.xcodebuildresources then
			if type(project.xcodebuildresources) == "table" then
				res = project.xcodebuildresources
			end
		end

		local function checkItemInList(item, list)
			if item then
				if list then
					if type(list) == "table" then
						for _,v in pairs(list) do
							if string.find(item, v, 1, true) then
								return true
							end
						end
					end
				end
			end
			return false
		end

		--print (node.path, node.buildid, node.cfg, res)
		if (checkItemInList(node.path, res)) then
			return true
		end

		return false
	end

--
-- Return 'explicitFileType' if the given file is being set with 'compileas'
--

	function xcode.getfiletypekey(node, cfg)
		if node.configs then
			local filecfg = fileconfig.getconfig(node, cfg)
			if filecfg and filecfg["compileas"] then
				return "explicitFileType"
			end
		end
		return "lastKnownFileType"
	end
--
-- Return the Xcode type for a given file, based on the file extension.
--
-- @param fname
--    The file name to identify.
-- @returns
--    An Xcode file type, string.
--

	function xcode.getfiletype(node, cfg)

		if node.configs then
			local filecfg = fileconfig.getconfig(node, cfg)
			if filecfg then
				if p.languages.isc(filecfg.compileas) then
					return "sourcecode.c.c"
				elseif p.languages.iscpp(filecfg.compileas) then
					return "sourcecode.cpp.cpp"
				elseif filecfg.language == "ObjC" then
					return "sourcecode.c.objc"
				elseif 	filecfg.language == "ObjCpp" then
					return "sourcecode.cpp.objcpp"
				end
			end
		end

		local types = {
			[".c"]         = "sourcecode.c.c",
			[".cc"]        = "sourcecode.cpp.cpp",
			[".cpp"]       = "sourcecode.cpp.cpp",
			[".css"]       = "text.css",
			[".cxx"]       = "sourcecode.cpp.cpp",
			[".S"]         = "sourcecode.asm.asm",
			[".framework"] = "wrapper.framework",
			[".gif"]       = "image.gif",
			[".h"]         = "sourcecode.c.h",
			[".html"]      = "text.html",
			[".lua"]       = "sourcecode.lua",
			[".m"]         = "sourcecode.c.objc",
			[".mm"]        = "sourcecode.cpp.objc",
			[".nib"]       = "wrapper.nib",
			[".storyboard"] = "file.storyboard",
			[".pch"]       = "sourcecode.c.h",
			[".plist"]     = "text.plist.xml",
			[".strings"]   = "text.plist.strings",
			[".xib"]       = "file.xib",
			[".icns"]      = "image.icns",
			[".s"]         = "sourcecode.asm",
			[".bmp"]       = "image.bmp",
			[".wav"]       = "audio.wav",
			[".xcassets"]  = "folder.assetcatalog",
			[".swift"]     = "sourcecode.swift",
		}
		return types[path.getextension(node.path)] or "text"
	end

--
-- Print user configuration references contained in xcodeconfigreferences
-- @param offset
--    offset used by function _p
-- @param cfg
--    configuration
--

	local function xcodePrintUserConfigReferences(offset, cfg, tr, kind)
		local referenceName
		if kind == "project" then
			referenceName = cfg.xcodeconfigreferenceproject
		elseif kind == "target" then
			referenceName = cfg.xcodeconfigreferencetarget
		end
		tree.traverse(tr, {
			onleaf = function(node)
				filename = node.name
				if node.id and path.getextension(filename) == ".xcconfig" then
					if filename == referenceName then
						_p(offset, 'baseConfigurationReference = %s /* %s */;', node.id, filename)
						return
					end
				end
			end
		}, false)
	end



	local escapeSpecialChars = {
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
	}

	local function escapeChar(c)
		return escapeSpecialChars[c] or '\\'..c
	end

	local function escapeArg(value)
		value = value:gsub('[\'"\\\n\r\t ]', escapeChar)
		return value
	end

	local function escapeSetting(value)
		value = value:gsub('["\\\n\r\t]', escapeChar)
		return value
	end

	local function stringifySetting(value)
		if type(value) == 'boolean' then
			value = iif(value, "YES", "NO")
		end
		value = value..''
		if not value:match('^[%a%d_./]+$') then
			value = '"'..escapeSetting(value)..'"'
		end
		return value
	end

	local function customStringifySetting(value)
		value = value..''

		local test = value:match('^[%a%d_./%+]+$')
		if test then
			value = '"'..escapeSetting(value)..'"'
		end
		return value
	end

	local function skipSetting(value)
		return value == false
	end

	local function printSetting(level, name, value)
		if type(value) == 'function' then
			value(level, name)
		elseif type(value) ~= 'table' then
			if not skipSetting(value) then
				_p(level, '%s = %s;', stringifySetting(name), stringifySetting(value))
			end
		else
			for k, v in pairs(value) do
				if skipSetting(v) then
					value[k] = nil
				end
			end
			if #value == 1 then
				_p(level, '%s = %s;', stringifySetting(name), stringifySetting(value[1]))
			end
			if #value > 1 then
				_p(level, '%s = (', stringifySetting(name))
				for _, item in ipairs(value) do
					_p(level + 1, '%s,', stringifySetting(item))
				end
				_p(level, ');')
			end
		end
	end

	local function convertSetting(value)
		if type(value) ~= 'table' then
			return stringifySetting(value)
		elseif #value >= 1 then
			local r = '('
			for _, v in ipairs(value) do
				r = r..string.format('%s, ', convertSetting(v))
			end
			return r..');'
		else
			local r = '{'
			for k, v in pairs(value) do
				r = r..string.format('%s = %s ', stringifySetting(k), convertSetting(v))
			end
			return r..'};'
		end
	end

	local function printSettingsTable(level, settings)
		-- Maintain alphabetic order to be consistent
		local keys = table.keys(settings)
		table.sort(keys)
		for _, k in ipairs(keys) do
			printSetting(level, k, settings[k])
		end
	end

	local function overrideSettings(settings, overrides)
		if type(overrides) == 'table' then
			for name, value in pairs(overrides) do
				-- Allow an override to remove a value by using false
				settings[name] = iif(not table.equals(value, { false }), value, nil)
			end
		end
	end

--
-- Return the Xcode product type, based target kind.
--
-- @param node
--    The product node to identify.
-- @returns
--    An Xcode product type, string.
--

	function xcode.getproducttype(node)
		local types = {
			ConsoleApp   = "com.apple.product-type.tool",
			WindowedApp  = "com.apple.product-type.application",
			StaticLib    = "com.apple.product-type.library.static",
			SharedLib    = "com.apple.product-type.library.dynamic",
			OSXBundle    = "com.apple.product-type.bundle",
			OSXFramework = "com.apple.product-type.framework",
			XCTest       = "com.apple.product-type.bundle.unit-test",
		}
		return types[iif(node.cfg.kind == "SharedLib" and node.cfg.sharedlibtype, node.cfg.sharedlibtype, node.cfg.kind)]
	end


--
-- Return the Xcode target type, based on the target file extension.
--
-- @param node
--    The product node to identify.
-- @returns
--    An Xcode target type, string.
--

	function xcode.gettargettype(node)
		local types = {
			ConsoleApp   = "\"compiled.mach-o.executable\"",
			WindowedApp  = "wrapper.application",
			StaticLib    = "archive.ar",
			SharedLib    = "\"compiled.mach-o.dylib\"",
			OSXBundle    = "wrapper.cfbundle",
			OSXFramework = "wrapper.framework",
			XCTest       = "wrapper.cfbundle",
		}
		return types[iif(node.cfg.kind == "SharedLib" and node.cfg.sharedlibtype, node.cfg.sharedlibtype, node.cfg.kind)]
	end

--
-- Return the Xcode debug information format for the current configuration
--
-- @param cfg
--    The current configuration
-- @returns
--    The corresponding value of DEBUG_INFORMATION_FORMAT, or 'dwarf-with-dsym' if invalid
--

	function xcode.getdebugformat(cfg)
		local formats = {
			["Dwarf"]      = "dwarf",
			["Default"]    = "dwarf-with-dsym",
			["SplitDwarf"] = "dwarf-with-dsym",
		}
		local rval = "dwarf-with-dsym"
		if cfg.debugformat then
			rval = formats[cfg.debugformat] or rval
		end
		return rval
	end

--
-- Return a unique file name for a project. Since Xcode uses .xcodeproj's to
-- represent both workspaces and projects there is a likely change of a name
-- collision. Tack on a number to differentiate them.
--
-- @param prj
--    The project being queried.
-- @returns
--    A uniqued file name
--

	function xcode.getxcodeprojname(prj)
		-- if there is a workspace with matching name, then use "projectname1.xcodeproj"
		-- just get something working for now
		local fname = p.filename(prj, ".xcodeproj")
		return fname
	end


--
-- Returns true if the file name represents a framework.
--
-- @param fname
--    The name of the file to test.
--

	function xcode.isframework(fname)
		return (path.getextension(fname) == ".framework")
	end


--
-- Retrieves a unique 12 byte ID for an object.
-- This function accepts an array of parameters that will be used to generate the id.
--
-- @returns
--    A 24-character string representing the 12 byte ID.
--

	function xcode.newid(...)
		local name = ''
		local arg = {...}
		for i, v in pairs(arg) do
			name = name..v..'****'
		end


		return ("%08X%08X%08X"):format(name:hash(16777619), name:hash(2166136261), name:hash(46577619))
	end


--
-- Create a product tree node and all projects in a workspace; assigning IDs
-- that are needed for inter-project dependencies.
--
-- @param wks
--    The workspace to prepare.
--

	function xcode.prepareWorkspace(wks)
		-- create and cache a list of supported platforms
		wks.xcode = { }

		for prj in p.workspace.eachproject(wks) do
			-- need a configuration to get the target information
			local cfg = project.getconfig(prj, prj.configurations[1], prj.platforms[1])

			-- build the product tree node
			local bundlepath = cfg.buildtarget.bundlename ~= "" and cfg.buildtarget.bundlename or cfg.buildtarget.name;
			if (prj.external) then
				bundlepath = cfg.project.name
			end

			local node = p.tree.new(path.getname(bundlepath))

			node.cfg = cfg
			node.id = xcode.newid(node.name, "product")
			node.targetid = xcode.newid(node.name, "target")

			-- attach it to the project
			prj.xcode = {}
			prj.xcode.projectnode = node
		end
	end


---------------------------------------------------------------------------
-- Section generator functions, in the same order in which they appear
-- in the .pbxproj file
---------------------------------------------------------------------------

	function xcode.PBXBuildFile(tr)
		local settings = {};
		local cfg = project.getfirstconfig(tr.project)

		local function getsuffix(node)
			if cfg and cfg.xcodebuildfilesettings then
				local nodename = path.getname(node.path)
				local settings = cfg.xcodebuildfilesettings[nodename]
				if settings then
					return string.format("settings = %s ", convertSetting(settings))
				end
			end
			return ""
		end

		tree.traverse(tr, {
			onnode = function(node)
				if node.buildid then
					settings[node.buildid] = function(level)
						_p(level,'%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; %s};',
							node.buildid, node.name, xcode.getbuildcategory(node), node.id, node.name, getsuffix(node))
					end
				end
			end
		})

		if not table.isempty(settings) then
			_p('/* Begin PBXBuildFile section */')
			printSettingsTable(2, settings);
			_p('/* End PBXBuildFile section */')
			_p('')
		end
	end


	function xcode.PBXContainerItemProxy(tr)
		local settings = {}
		for _, node in ipairs(tr.projects.children) do
			settings[node.productproxyid] = function()
				_p(2,'%s /* PBXContainerItemProxy */ = {', node.productproxyid)
				_p(3,'isa = PBXContainerItemProxy;')
				_p(3,'containerPortal = %s /* %s */;', node.id, path.getrelative(node.parent.parent.project.location, node.path))
				_p(3,'proxyType = 2;')
				_p(3,'remoteGlobalIDString = %s;', node.project.xcode.projectnode.id)
				_p(3,'remoteInfo = %s;', stringifySetting(node.project.xcode.projectnode.name))
				_p(2,'};')
			end
			settings[node.targetproxyid] = function()
				_p(2,'%s /* PBXContainerItemProxy */ = {', node.targetproxyid)
				_p(3,'isa = PBXContainerItemProxy;')
				_p(3,'containerPortal = %s /* %s */;', node.id, path.getrelative(node.parent.parent.project.location, node.path))
				_p(3,'proxyType = 1;')
				_p(3,'remoteGlobalIDString = %s;', node.project.xcode.projectnode.targetid)
				_p(3,'remoteInfo = %s;', stringifySetting(node.project.xcode.projectnode.name))
				_p(2,'};')
			end
		end

		if not table.isempty(settings) then
			_p('/* Begin PBXContainerItemProxy section */')
			printSettingsTable(2, settings);
			_p('/* End PBXContainerItemProxy section */')
			_p('')
		end
	end


	function xcode.PBXFileReference(tr)
		local cfg = project.getfirstconfig(tr.project)
		local settings = {}

		tree.traverse(tr, {
			onleaf = function(node)
				-- I'm only listing files here, so ignore anything without a path
				if not node.path then
					return
				end

				-- is this the product node, describing the output target?
				if node.kind == "product" then
					settings[node.id] = function(level)
						_p(level,'%s /* %s */ = {isa = PBXFileReference; explicitFileType = %s; includeInIndex = 0; name = %s; path = %s; sourceTree = BUILT_PRODUCTS_DIR; };',
							node.id, node.name, xcode.gettargettype(node), stringifySetting(node.name), stringifySetting(path.getname(node.cfg.buildtarget.bundlename ~= "" and node.cfg.buildtarget.bundlename or node.cfg.buildtarget.relpath)))
					end
				-- is this a project dependency?
				elseif node.parent.parent == tr.projects then
					settings[node.parent.id] = function(level)
						-- ms Is there something wrong with path is relative ?
						-- if we have a and b without slashes get relative should assume the same parent folder and return ../
						-- this works if we put it like below
						local relpath = path.getrelative(path.getabsolute(tr.project.location), path.getabsolute(node.parent.project.location))
						_p(level,'%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = "wrapper.pb-project"; name = %s; path = %s; sourceTree = SOURCE_ROOT; };',
							node.parent.id, node.name, customStringifySetting(node.parent.name), stringifySetting(path.join(relpath, node.parent.name)))
					end
				-- something else
				else
					settings[node.id] = function(level)
					local pth, src
					if xcode.isframework(node.path) then
						--respect user supplied paths
						-- look for special variable-starting paths for different sources
						local nodePath = node.path
						local _, matchEnd, variable = string.find(nodePath, "^%$%((.+)%)/")
						if variable then
							-- by skipping the last '/' we support the same absolute/relative
							-- paths as before
							nodePath = string.sub(nodePath, matchEnd + 1)
						end
						if string.find(nodePath,'/')  then
							if string.find(nodePath,'^%.')then
								--error('relative paths are not currently supported for frameworks')
								pth = path.getrelative(tr.project.location, node.path)
								--print(tr.project.location, node.path , pth)
								src = "SOURCE_ROOT"
								variable = src
							else
								pth = nodePath
								src = "<absolute>"
							end
						end
						-- if it starts with a variable, use that as the src instead
						if variable then
							src = variable
							-- if we are using a different source tree, it has to be relative
							-- to that source tree, so get rid of any leading '/'
							if string.find(pth, '^/') then
								pth = string.sub(pth, 2)
							end
						else
							pth = "System/Library/Frameworks/" .. node.path
							src = "SDKROOT"
						end
					else
						-- something else; probably a source code file
						src = "<group>"

						if node.abspath then
							pth = path.getrelative(tr.project.location, node.abspath)
						else
							pth = node.path
						end
						--end
						end
						_p(level,'%s /* %s */ = {isa = PBXFileReference; %s = %s; name = %s; path = %s; sourceTree = %s; };',
							node.id, node.name, xcode.getfiletypekey(node, cfg), xcode.getfiletype(node, cfg), stringifySetting(node.name), stringifySetting(pth), stringifySetting(src))
					end
				end
			end
		})

		if not table.isempty(settings) then
			_p('/* Begin PBXFileReference section */')
			printSettingsTable(2, settings)
			_p('/* End PBXFileReference section */')
			_p('')
		end
	end


	function xcode.PBXFrameworksBuildPhase(tr)
		_p('/* Begin PBXFrameworksBuildPhase section */')
		_p(2,'%s /* Frameworks */ = {', tr.products.children[1].fxstageid)
		_p(3,'isa = PBXFrameworksBuildPhase;')
		_p(3,'buildActionMask = 2147483647;')
		_p(3,'files = (')

		-- write out library dependencies
		tree.traverse(tr.frameworks, {
			onleaf = function(node)
				if node.buildid then
					_p(4,'%s /* %s in Frameworks */,', node.buildid, node.name)
				end
			end
		})

		-- write out project dependencies
		tree.traverse(tr.projects, {
			onleaf = function(node)
				if node.buildid then
					_p(4,'%s /* %s in Frameworks */,', node.buildid, node.name)
				end
			end
		})

		_p(3,');')
		_p(3,'runOnlyForDeploymentPostprocessing = 0;')
		_p(2,'};')
		_p('/* End PBXFrameworksBuildPhase section */')
		_p('')
	end


	function xcode.PBXGroup(tr)
		local settings = {}

		tree.traverse(tr, {
			onnode = function(node)
				-- Skip over anything that isn't a proper group
				if (node.path and #node.children == 0) or node.kind == "vgroup" then
					return
				end

				local function isAggregateTarget(node)
					local productsId = xcode.newid("Products")
					return node.id == productsId and node.parent.project and node.parent.project.kind == "Utility"
				end
				if isAggregateTarget(node) then
					return
				end

				settings[node.productgroupid or node.id] = function()
					-- project references get special treatment
					if node.parent == tr.projects then
						_p(2,'%s /* Products */ = {', node.productgroupid)
					else
						_p(2,'%s /* %s */ = {', node.id, node.name)
					end

					_p(3,'isa = PBXGroup;')
					_p(3,'children = (')
					for _, childnode in ipairs(node.children) do
						if not isAggregateTarget(childnode) then
							_p(4,'%s /* %s */,', childnode.id, childnode.name)
						end
					end
					_p(3,');')

					if node.parent == tr.projects then
						_p(3,'name = Products;')
					else
						_p(3,'name = %s;', stringifySetting(node.name))

						local vpath = project.getvpath(tr.project, node.name)

						if node.path and node.name ~= vpath then
							local p = node.path
							if node.parent.path then
								p = path.getrelative(node.parent.path, node.path)
							end
							_p(3,'path = %s;', stringifySetting(p))
						end
					end

					_p(3,'sourceTree = "<group>";')
					_p(2,'};')
				end
			end
		}, true)

		if not table.isempty(settings) then
			_p('/* Begin PBXGroup section */')
			printSettingsTable(2, settings)
			_p('/* End PBXGroup section */')
			_p('')
		end
	end

	local function xcode_GetBuildCommands(tr)
		local buildCommandInfos = {}
		tree.traverse(tr, {
			onnode = function(node)
				if node.buildcommandid then
					local info = {
						node = node,
						inputs = { node.relpath },
						outputs = {},
						depends = {},
						transact = false,
					}
					for cfg in project.eachconfig(tr.project) do
						local filecfg = fileconfig.getconfig(node, cfg)
						if filecfg then
							for _, v in ipairs(filecfg.buildinputs) do
								table.insert(info.inputs, project.getrelative(tr.project, v))
							end
							for _, v in ipairs(filecfg.buildoutputs) do
								table.insert(info.outputs, project.getrelative(tr.project, v))
							end
						end
					end
					table.insert(buildCommandInfos, info)
				end
			end
		})
		for _, mine in ipairs(buildCommandInfos) do
			for _, their in ipairs(buildCommandInfos) do
				if mine ~= their then
					for _, input in ipairs(mine.inputs) do
						if table.contains(their.outputs, input) then
							table.insert(mine.depends, their)
							break
						end
					end
				end
			end
		end
		local buildCommands = {}
		local leftover = #buildCommandInfos
		while leftover > 0 do
			local prev = leftover
			for _, info in ipairs(buildCommandInfos) do
				if not info.transact then
					local transact = true
					for _, depend in ipairs(info.depends) do
						transact = depend.transact
						if not transact then
							break
						end
					end
					if transact then
						table.insert(buildCommands, info.node)
						info.transact = true
						leftover = leftover - 1
					end
				end
			end
			if prev == leftover then
				error('detect circular reference.')
			end
		end
		return buildCommands
	end

	local function xcode_PBXAggregateOrNativeTarget(tr, pbxTargetName)
		local kinds = {
			Aggregate = {
				"Utility",
			},
			Native = {
				"ConsoleApp",
				"WindowedApp",
				"SharedLib",
				"StaticLib",
			},
		}
		local hasTarget = false
		for _, node in ipairs(tr.products.children) do
			hasTarget = table.contains(kinds[pbxTargetName], node.cfg.kind)
			if hasTarget then
				break
			end
		end
		if not hasTarget then
			return
		end

		_p('/* Begin PBX%sTarget section */', pbxTargetName)

		local buildCommands = xcode_GetBuildCommands(tr)

		for _, node in ipairs(tr.products.children) do
			local name = tr.project.name

			-- This function checks whether there are build commands of a specific
			-- type to be executed; they will be generated correctly, but the project
			-- commands will not contain any per-configuration commands, so the logic
			-- has to be extended a bit to account for that.
			local function hasBuildCommands(which)
				-- standard check...this is what existed before
				if #tr.project[which] > 0 then
					return true
				end
				-- what if there are no project-level commands? check configs...
				for _, cfg in ipairs(tr.configs) do
					if #cfg[which] > 0 then
						return true
					end
				end
			end

			_p(2,'%s /* %s */ = {', node.targetid, name)
			_p(3,'isa = PBX%sTarget;', pbxTargetName)
			_p(3,'buildConfigurationList = %s /* Build configuration list for PBX%sTarget "%s" */;', node.cfgsection, pbxTargetName, escapeSetting(name))
			_p(3,'buildPhases = (')
			if hasBuildCommands('prebuildcommands') then
				_p(4,'9607AE1010C857E500CD1376 /* Prebuild */,')
			end
			for _, v in ipairs(buildCommands) do
				_p(4,'%s /* Build "%s" */,', v.buildcommandid, v.name)
			end
			if pbxTargetName == "Native" then
				_p(4,'%s /* Resources */,', node.resstageid)
				_p(4,'%s /* Sources */,', node.sourcesid)
			end
			if hasBuildCommands('prelinkcommands') then
				_p(4,'9607AE3510C85E7E00CD1376 /* Prelink */,')
			end
			if pbxTargetName == "Native" then
				_p(4,'%s /* Frameworks */,', node.fxstageid)
			end
			if hasBuildCommands('postbuildcommands') then
				_p(4,'9607AE3710C85E8F00CD1376 /* Postbuild */,')
			end
			_p(3,');')
			_p(3,'buildRules = (')
			_p(3,');')

			_p(3,'dependencies = (')
			for _, node in ipairs(tr.projects.children) do
				_p(4,'%s /* PBXTargetDependency */,', node.targetdependid)
			end
			_p(3,');')

			_p(3,'name = %s;', stringifySetting(name))

			if pbxTargetName == "Native" then
				local p
				if node.cfg.kind == "ConsoleApp" then
					p = "$(HOME)/bin"
				elseif node.cfg.kind == "WindowedApp" then
					p = "$(HOME)/Applications"
				end
				if p then
					_p(3,'productInstallPath = %s;', stringifySetting(p))
				end
			end

			_p(3,'productName = %s;', stringifySetting(name))
			if pbxTargetName == "Native" then
				_p(3,'productReference = %s /* %s */;', node.id, node.name)
				_p(3,'productType = %s;', stringifySetting(xcode.getproducttype(node)))
			end
			_p(2,'};')
		end
		_p('/* End PBX%sTarget section */', pbxTargetName)
		_p('')
	end


	function xcode.PBXAggregateTarget(tr)
		xcode_PBXAggregateOrNativeTarget(tr, "Aggregate")
	end


	function xcode.PBXNativeTarget(tr)
		xcode_PBXAggregateOrNativeTarget(tr, "Native")
	end


	function xcode.PBXProject(tr)
		_p('/* Begin PBXProject section */')
		_p(2,'08FB7793FE84155DC02AAC07 /* Project object */ = {')
		_p(3,'isa = PBXProject;')
		_p(3,'attributes = {')
		_p(4,'TargetAttributes = {')
		for _, node in ipairs(tr.products.children) do
			_p(5,'%s = {', node.targetid)
			_p(6,'CreatedOnToolsVersion = 3.2;')
			if node.cfg.xcodedevelopmentteam then
				_p(6,'ProvisioningStyle = Automatic;')
				_p(6,'DevelopmentTeam = ' .. node.cfg.xcodedevelopmentteam .. ';')
			end
			_p(5,'};')
		end
		local capabilities = tr.project.xcodesystemcapabilities
		if not table.isempty(capabilities) then
			local keys = table.keys(capabilities)
			table.sort(keys)
			_p(5, '%s = {', tr.project.xcode.projectnode.targetid)
			_p(6, 'SystemCapabilities = {')
			for _, key in pairs(keys) do
				_p(7, '%s = {', key)
				_p(8, 'enabled = %d;', iif(capabilities[key], 1, 0))
				_p(7, '};')
			end
			_p(6, '};')
			_p(5, '};')
		end
		_p(4,'};')
		_p(3,'};')
		_p(3,'buildConfigurationList = 1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "%s" */;', tr.name)
		_p(3,'compatibilityVersion = "Xcode 3.2";')
		_p(3,'hasScannedForEncodings = 1;')
		_p(3,'mainGroup = %s /* %s */;', tr.id, tr.name)
		_p(3,'projectDirPath = "";')

		if #tr.projects.children > 0 then
			_p(3,'projectReferences = (')
			for _, node in ipairs(tr.projects.children) do
				_p(4,'{')
				_p(5,'ProductGroup = %s /* Products */;', node.productgroupid)
				_p(5,'ProjectRef = %s /* %s */;', node.id, path.getname(node.path))
				_p(4,'},')
			end
			_p(3,');')
		end

		_p(3,'projectRoot = "";')
		_p(3,'targets = (')
		for _, node in ipairs(tr.products.children) do
			_p(4,'%s /* %s */,', node.targetid, node.name)
		end
		_p(3,');')
		_p(2,'};')
		_p('/* End PBXProject section */')
		_p('')
	end


	function xcode.PBXReferenceProxy(tr)
		local settings = {}

		tree.traverse(tr.projects, {
			onleaf = function(node)
				settings[node.id] = function()
					_p(2,'%s /* %s */ = {', node.id, node.name)
					_p(3,'isa = PBXReferenceProxy;')
					_p(3,'fileType = %s;', xcode.gettargettype(node))
					_p(3,'path = %s;', stringifySetting(node.name))
					_p(3,'remoteRef = %s /* PBXContainerItemProxy */;', node.parent.productproxyid)
					_p(3,'sourceTree = BUILT_PRODUCTS_DIR;')
					_p(2,'};')
				end
			end
		})

		if not table.isempty(settings) then
			_p('/* Begin PBXReferenceProxy section */')
			printSettingsTable(2, settings)
			_p('/* End PBXReferenceProxy section */')
			_p('')
		end
	end


	function xcode.PBXResourcesBuildPhase(tr)
		_p('/* Begin PBXResourcesBuildPhase section */')
		for _, target in ipairs(tr.products.children) do
			_p(2,'%s /* Resources */ = {', target.resstageid)
			_p(3,'isa = PBXResourcesBuildPhase;')
			_p(3,'buildActionMask = 2147483647;')
			_p(3,'files = (')
			tree.traverse(tr, {
				onnode = function(node)
					if xcode.getbuildcategory(node) == "Resources" then
						_p(4,'%s /* %s in Resources */,', node.buildid, node.name)
					end
				end
			})
			_p(3,');')
			_p(3,'runOnlyForDeploymentPostprocessing = 0;')
			_p(2,'};')
		end
		_p('/* End PBXResourcesBuildPhase section */')
		_p('')
	end

	function xcode.PBXShellScriptBuildPhase(tr)
		local wrapperWritten = false

		local function doblock(id, name, which)
			-- start with the project-level commands (most common)
			local prjcmds = tr.project[which]
			local commands = table.join(prjcmds, {})

			-- see if there are any config-specific commands to add
			for _, cfg in ipairs(tr.configs) do
				local cfgcmds = cfg[which]
				if #cfgcmds > #prjcmds then
					table.insert(commands, 'if [ "${CONFIGURATION}" = "' .. cfg.buildcfg .. '" ]; then')
					for i = #prjcmds + 1, #cfgcmds do
						table.insert(commands, cfgcmds[i])
					end
					table.insert(commands, 'fi')
				end
			end

			if #commands > 0 then
				table.insert(commands, 1, 'set -e') -- Tells the shell to exit when any command fails
				commands = os.translateCommands(commands, p.MACOSX)
				if not wrapperWritten then
					_p('/* Begin PBXShellScriptBuildPhase section */')
					wrapperWritten = true
				end
				_p(2,'%s /* %s */ = {', id, name)
				_p(3,'isa = PBXShellScriptBuildPhase;')
				_p(3,'buildActionMask = 2147483647;')
				_p(3,'files = (')
				_p(3,');')
				_p(3,'inputPaths = (');
				_p(3,');');
				_p(3,'name = %s;', name);
				_p(3,'outputPaths = (');
				_p(3,');');
				_p(3,'runOnlyForDeploymentPostprocessing = 0;');
				_p(3,'shellPath = /bin/sh;');
				_p(3,'shellScript = %s;', stringifySetting(table.concat(commands, '\n')))
				_p(2,'};')
			end
		end

		doblock("9607AE1010C857E500CD1376", "Prebuild", "prebuildcommands")

		local settings = {}
		tree.traverse(tr, {
			onnode = function(node)
				if node.buildcommandid then
					settings[node.buildcommandid] = function(level)
						local commands = {}
						local inputs = {}
						local outputs = {}
						for cfg in project.eachconfig(tr.project) do
							local filecfg = fileconfig.getconfig(node, cfg)
							if filecfg then
								table.insert(commands, 'if [ "${CONFIGURATION}" = "' .. cfg.buildcfg .. '" ]; then')
								if filecfg.buildmessage then
									table.insert(commands, '\techo "' .. filecfg.buildmessage .. '"')
								end
								local cmds = os.translateCommandsAndPaths(filecfg.buildcommands, filecfg.project.basedir, filecfg.project.location)
								for _, cmd in ipairs(cmds) do
									table.insert(commands, '\t' .. cmd)
								end
								table.insert(commands, 'fi')
								for _, v in ipairs(filecfg.buildinputs) do
									inputs[v] = true
								end
								for _, v in ipairs(filecfg.buildoutputs) do
									outputs[v] = true
								end
							end
						end

						if #commands > 0 then
							table.insert(commands, 1, 'set -e') -- Tells the shell to exit when any command fails
						end

						_p(level,'%s /* Build "%s" */ = {', node.buildcommandid, node.name)
						_p(level+1,'isa = PBXShellScriptBuildPhase;')
						_p(level+1,'buildActionMask = 2147483647;')
						_p(level+1,'files = (')
						_p(level+1,');')
						_p(level+1,'inputPaths = (');
						_p(level+2,'"%s",', escapeSetting(node.relpath))
						for v, _ in pairs(inputs) do
							_p(level+2,'"%s",', escapeSetting(project.getrelative(tr.project, v)))
						end
						_p(level+1,');')
						_p(level+1,'name = %s;', stringifySetting('Build "' .. node.name .. '"'))
						_p(level+1,'outputPaths = (')
						for v, _ in pairs(outputs) do
							_p(level+2,'"%s",', escapeSetting(project.getrelative (tr.project, v)))
						end
						_p(level+1,');')
						_p(level+1,'runOnlyForDeploymentPostprocessing = 0;');
						_p(level+1,'shellPath = /bin/sh;');
						_p(level+1,'shellScript = %s;', stringifySetting(table.concat(commands, '\n')))
						_p(level,'};')
					end
				end
			end
		})

		if not table.isempty(settings) then
			if not wrapperWritten then
				_p('/* Begin PBXShellScriptBuildPhase section */')
				wrapperWritten = true
			end
			printSettingsTable(2, settings)
		end

		doblock("9607AE3510C85E7E00CD1376", "Prelink", "prelinkcommands")
		doblock("9607AE3710C85E8F00CD1376", "Postbuild", "postbuildcommands")

		if wrapperWritten then
			_p('/* End PBXShellScriptBuildPhase section */')
			_p('')
		end
	end


	function xcode.PBXSourcesBuildPhase(tr)
		_p('/* Begin PBXSourcesBuildPhase section */')
		for _, target in ipairs(tr.products.children) do
			_p(2,'%s /* Sources */ = {', target.sourcesid)
			_p(3,'isa = PBXSourcesBuildPhase;')
			_p(3,'buildActionMask = 2147483647;')
			_p(3,'files = (')
			tree.traverse(tr, {
				onleaf = function(node)
					if xcode.getbuildcategory(node) == "Sources" and node.buildid then
						_p(4,'%s /* %s in Sources */,', node.buildid, node.name)
					end
				end
			})
			_p(3,');')
			_p(3,'runOnlyForDeploymentPostprocessing = 0;')
			_p(2,'};')
		end
		_p('/* End PBXSourcesBuildPhase section */')
		_p('')
	end


	function xcode.PBXVariantGroup(tr)
		local settings = {}
		tree.traverse(tr, {
			onbranch = function(node)
				settings[node.id] = function()
					if node.kind == "vgroup" then
						_p(2,'%s /* %s */ = {', node.id, node.name)
						_p(3,'isa = PBXVariantGroup;')
						_p(3,'children = (')
						for _, lang in ipairs(node.children) do
							_p(4,'%s /* %s */,', lang.id, lang.name)
						end
						_p(3,');')
						_p(3,'name = %s;', node.name)
						_p(3,'sourceTree = "<group>";')
						_p(2,'};')
					end
				end
			end
		})

		if not table.isempty(settings) then
			_p('/* Begin PBXVariantGroup section */')
			printSettingsTable(2, settings)
			_p('/* End PBXVariantGroup section */')
			_p('')
		end
	end


	function xcode.PBXTargetDependency(tr)
		local settings = {}
		tree.traverse(tr.projects, {
			onleaf = function(node)
				settings[node.parent.targetdependid] = function()
					_p(2,'%s /* PBXTargetDependency */ = {', node.parent.targetdependid)
					_p(3,'isa = PBXTargetDependency;')
					_p(3,'name = %s;', stringifySetting(node.name))
					_p(3,'targetProxy = %s /* PBXContainerItemProxy */;', node.parent.targetproxyid)
					_p(2,'};')
				end
			end
		})

		if not table.isempty(settings) then
			_p('/* Begin PBXTargetDependency section */')
			printSettingsTable(2, settings)
			_p('/* End PBXTargetDependency section */')
			_p('')
		end
	end


	function xcode.XCBuildConfiguration_Target(tr, target, cfg)
		local settings = {}

		settings['ALWAYS_SEARCH_USER_PATHS'] = 'NO'

		if cfg.symbols ~= p.OFF then
			settings['DEBUG_INFORMATION_FORMAT'] = xcode.getdebugformat(cfg)
		end

		if cfg.kind ~= "StaticLib" and cfg.buildtarget.prefix ~= '' then
			settings['EXECUTABLE_PREFIX'] = cfg.buildtarget.prefix
		end

		if cfg.buildtarget.extension then
			local exts = {
				WindowedApp  = "app",
				SharedLib    = "dylib",
				StaticLib    = "a",
				OSXBundle    = "bundle",
				OSXFramework = "framework",
				XCTest       = "xctest",
			}
			local ext = cfg.buildtarget.extension:sub(2)
			if ext ~= exts[iif(cfg.kind == "SharedLib" and cfg.sharedlibtype, cfg.sharedlibtype, cfg.kind)] then
				if cfg.kind == "WindowedApp" or (cfg.kind == "SharedLib" and cfg.sharedlibtype) then
					settings['WRAPPER_EXTENSION'] = ext
				elseif cfg.kind == "SharedLib" or cfg.kind == "StaticLib" then
					settings['EXECUTABLE_EXTENSION'] = ext
				end
			end
		end

		local outdir = path.getrelative(tr.project.location, path.getdirectory(cfg.buildtarget.relpath))
		if outdir ~= "." then
			settings['CONFIGURATION_BUILD_DIR'] = outdir
		end

		settings['GCC_DYNAMIC_NO_PIC'] = 'NO'

		if tr.infoplist then
			settings['INFOPLIST_FILE'] = config.findfile(cfg, path.getextension(tr.infoplist.name))
		end

		local installpaths = {
			ConsoleApp = '/usr/local/bin',
			WindowedApp = '"$(HOME)/Applications"',
			SharedLib = '/usr/local/lib',
			StaticLib = '/usr/local/lib',
			OSXBundle = '$(LOCAL_LIBRARY_DIR)/Bundles',
			OSXFramework = '$(LOCAL_LIBRARY_DIR)/Frameworks',
		}
		settings['INSTALL_PATH'] = installpaths[iif(cfg.kind == "SharedLib" and cfg.sharedlibtype, cfg.sharedlibtype, cfg.kind)]

		local fileNameList = {}
		local file_tree = project.getsourcetree(tr.project)
		tree.traverse(tr, {
				onnode = function(node)
					if node.buildid and not node.isResource and node.abspath then
						-- ms this seems to work on visual studio !!!
						-- why not in xcode ??
						local filecfg = fileconfig.getconfig(node, cfg)
						if filecfg and filecfg.flags.ExcludeFromBuild then
						--fileNameList = fileNameList .. " " ..filecfg.name
							table.insert(fileNameList, escapeArg(node.name))
						end

						--ms new way
						-- if the file is not in this config file list excluded it from build !!!
						--if not cfg.files[node.abspath] then
						--	table.insert(fileNameList, escapeArg(node.name))
						--end
					end
				end
			})

		if not table.isempty(fileNameList) then
			settings['EXCLUDED_SOURCE_FILE_NAMES'] = fileNameList
		end
		settings['PRODUCT_NAME'] = iif(cfg.kind == "ConsoleApp" and cfg.buildtarget.extension, cfg.buildtarget.basename .. cfg.buildtarget.extension, cfg.buildtarget.basename)

		if os.istarget(p.IOS) then
			settings['SDKROOT'] = 'iphoneos'

			settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = cfg.xcodecodesigningidentity or 'iPhone Developer'

			local minOSVersion = project.systemversion(cfg)
			if minOSVersion ~= nil then
				settings['IPHONEOS_DEPLOYMENT_TARGET'] = minOSVersion
			end

			local families = {
				['iPhone/iPod touch'] = '1',
				['iPad'] = '2',
				['Universal'] = '1,2',
			}
			local family = families[cfg.iosfamily]
			if family then
				settings['TARGETED_DEVICE_FAMILY'] = family
			end
		else
			local minOSVersion = project.systemversion(cfg)
			if minOSVersion ~= nil then
				settings['MACOSX_DEPLOYMENT_TARGET'] = minOSVersion
			end
		end

		--ms not by default ...add it manually if you need it
		--settings['COMBINE_HIDPI_IMAGES'] = 'YES'

		overrideSettings(settings, cfg.xcodebuildsettings)

		_p(2,'%s /* %s */ = {', cfg.xcode.targetid, cfg.buildcfg)
		_p(3,'isa = XCBuildConfiguration;')
		xcodePrintUserConfigReferences(3, cfg, tr, "target")
		_p(3,'buildSettings = {')
		printSettingsTable(4, settings)
		_p(3,'};')
		printSetting(3, 'name', cfg.buildcfg);
		_p(2,'};')
	end


	xcode.cLanguageStandards = {
		["Default"] = "compiler-default",  -- explicit compiler default
		["C89"] = "c89",
		["C90"] = "c90",
		["C99"] = "c99",
		["C11"] = "c11",
		["gnu89"] = "gnu89",
		["gnu90"] = "gnu90",
		["gnu99"] = "gnu99",
		["gnu11"] = "gnu11"
	}

	function xcode.XCBuildConfiguration_CLanguageStandard(settings, cfg)
		-- if no cppdialect is provided, don't set C dialect
		-- projects without C dialect set will use compiler default
		if not cfg.cdialect then
			return
		end

		local cLanguageStandard = xcode.cLanguageStandards[cfg.cdialect]
		if cLanguageStandard then
			settings['GCC_C_LANGUAGE_STANDARD'] = cLanguageStandard
		end
	end


	xcode.cppLanguageStandards = {
		["Default"] = "compiler-default",  -- explicit compiler default
		["C++98"] = "c++98",
		["C++11"] = "c++11",
		["C++14"] = "c++14",
		["C++17"] = "c++1z",
		["gnu++98"] = "gnu++98",
		["gnu++11"] = "gnu++0x",  -- Xcode project GUI uses gnu++0x, but gnu++11 also works
		["gnu++14"] = "gnu++14",
		["gnu++17"] = "gnu++1z"
	}

	function xcode.XCBuildConfiguration_CppLanguageStandard(settings, cfg)
		-- if no cppdialect is provided, don't set C++ dialect
		-- projects without C++ dialect set will use compiler default
		if not cfg.cppdialect then
			return
		end

		local cppLanguageStandard = xcode.cppLanguageStandards[cfg.cppdialect]
		if cppLanguageStandard then
			settings['CLANG_CXX_LANGUAGE_STANDARD'] = cppLanguageStandard
		end
	end

	function xcode.XCBuildConfiguration_SwiftLanguageVersion(settings, cfg)
		-- if no swiftversion is provided, don't set swift version
		-- Projects with swift files but without swift version will refuse 
		-- to build on Xcode but setting a default SWIFT_VERSION may have 
		-- unexpected interactions with other systems like cocoapods
		if not cfg.swiftversion then
			return
		else
			settings['SWIFT_VERSION'] = cfg.swiftversion
		end
	end

	local function quoted(str, cfg)
		return p.quoted(str, cfg.xcodequotedexceptions)
	end

	function xcode.XCBuildConfiguration_Project(tr, cfg)
		local settings = {}

		local archs = {
			Native = "$(NATIVE_ARCH_ACTUAL)",
			x86    = "i386",
			x86_64 = "x86_64",
			Universal32 = "$(ARCHS_STANDARD_32_BIT)",
			Universal64 = "$(ARCHS_STANDARD_64_BIT)",
			Universal = "$(ARCHS_STANDARD_32_64_BIT)",
		}

		settings['ARCHS'] = archs[cfg.platform or "Native"]

		--ms This is the default so don;t write it
		--settings['SDKROOT'] = 'macosx'

		local targetdir = path.getdirectory(cfg.buildtarget.relpath)
		if targetdir ~= "." then
			settings['CONFIGURATION_BUILD_DIR'] = '$(SYMROOT)'
		end

		settings['CONFIGURATION_TEMP_DIR'] = '$(OBJROOT)'

		if config.isDebugBuild(cfg) then
			settings['COPY_PHASE_STRIP'] = 'NO'
		end

		xcode.XCBuildConfiguration_CLanguageStandard(settings, cfg)
		xcode.XCBuildConfiguration_CppLanguageStandard(settings, cfg)

		if cfg.exceptionhandling == p.OFF then
			settings['GCC_ENABLE_CPP_EXCEPTIONS'] = 'NO'
		end

		if cfg.rtti == p.OFF then
			settings['GCC_ENABLE_CPP_RTTI'] = 'NO'
		end

		if cfg.symbols == p.ON and cfg.editandcontinue ~= "Off" then
			settings['GCC_ENABLE_FIX_AND_CONTINUE'] = 'YES'
		end

		if cfg.exceptionhandling == p.OFF then
			settings['GCC_ENABLE_OBJC_EXCEPTIONS'] = 'NO'
		end

		local optimizeMap = { On = 3, Size = 's', Speed = 3, Full = 'fast', Debug = 1 }
		settings['GCC_OPTIMIZATION_LEVEL'] = optimizeMap[cfg.optimize] or 0

		if cfg.pchheader and not cfg.flags.NoPCH then
			settings['GCC_PRECOMPILE_PREFIX_HEADER'] = 'YES'
			settings['GCC_PREFIX_HEADER'] = cfg.pchheader
		end

		local escapedDefines = { }
		for i,v in ipairs(cfg.defines) do
			escapedDefines[i] = escapeArg(v)
		end
		settings['GCC_PREPROCESSOR_DEFINITIONS'] = escapedDefines

		settings["GCC_SYMBOLS_PRIVATE_EXTERN"] = 'NO'

		if cfg.unsignedchar ~= nil then
			settings['GCC_CHAR_IS_UNSIGNED_CHAR'] = iif(cfg.unsignedchar, "YES", "NO")
		end

		if cfg.flags.FatalWarnings then
			settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'YES'
		end

		settings['GCC_WARN_ABOUT_RETURN_TYPE'] = 'YES'
		settings['GCC_WARN_UNUSED_VARIABLE'] = 'YES'

		local includedirs = project.getrelative(cfg.project, cfg.includedirs)
		for i,v in ipairs(includedirs) do
			cfg.includedirs[i] = quoted(v, cfg)
		end
		settings['USER_HEADER_SEARCH_PATHS'] = cfg.includedirs

		local sysincludedirs = project.getrelative(cfg.project, cfg.sysincludedirs)
		for i,v in ipairs(sysincludedirs) do
			cfg.sysincludedirs[i] = quoted(v, cfg)
		end
		if not table.isempty(cfg.sysincludedirs) then
			table.insert(cfg.sysincludedirs, "$(inherited)")
		end
		settings['HEADER_SEARCH_PATHS'] = cfg.sysincludedirs

		for i,v in ipairs(cfg.libdirs) do
			v = p.project.getrelative(cfg.project, v)
			cfg.libdirs[i] = quoted(v, cfg)
		end
		settings['LIBRARY_SEARCH_PATHS'] = cfg.libdirs

		for i,v in ipairs(cfg.frameworkdirs) do
			v = p.project.getrelative(cfg.project, v)
			cfg.frameworkdirs[i] = quoted(v, cfg)
		end
		settings['FRAMEWORK_SEARCH_PATHS'] = cfg.frameworkdirs

		local objDir = path.getrelative(tr.project.location, cfg.objdir)
		settings['OBJROOT'] = objDir

		settings['ONLY_ACTIVE_ARCH'] = iif(p.config.isDebugBuild(cfg), 'YES', 'NO')

		-- build list of "other" C/C++ flags
		local checks = {
			["-ffast-math"]             = cfg.floatingpoint == "Fast",
			["-fomit-frame-pointer"]    = cfg.omitframepointer == "On",
			["-fno-omit-frame-pointer"] = cfg.omitframepointer == "Off",
		}

		local flags = { }
		for flag, check in pairs(checks) do
			if check then
				table.insert(flags, flag)
			end
		end


		--[[if (type(cfg.buildoptions) == "table") then
			for k,v in pairs(cfg.buildoptions) do
				table.insertflat(flags, string.explode(v," -"))
			end
		end
		]]

		settings['OTHER_CFLAGS'] = table.join(flags, cfg.buildoptions)

		-- build list of "other" linked flags. All libraries that aren't frameworks
		-- are listed here, so I don't have to try and figure out if they are ".a"
		-- or ".dylib", which Xcode requires to list in the Frameworks section
		flags = { }
		for _, lib in ipairs(config.getlinks(cfg, "system")) do
			if not xcode.isframework(lib) then
				table.insert(flags, "-l" .. lib)
			end
		end

		--ms this step is for reference projects only
		for _, lib in ipairs(config.getlinks(cfg, "dependencies", "object")) do
			if (lib.external) then
				if not xcode.isframework(lib.linktarget.basename) then
					table.insert(flags, "-l" .. escapeArg(lib.linktarget.basename))
				end
			end
		end

		settings['OTHER_LDFLAGS'] = table.join(flags, cfg.linkoptions)

		if cfg.flags.StaticRuntime then
			settings['STANDARD_C_PLUS_PLUS_LIBRARY_TYPE'] = 'static'
		end

		if targetdir ~= "." then
			settings['SYMROOT'] = path.getrelative(tr.project.location, targetdir)
		end

		if cfg.warnings == "Extra" then
			settings['WARNING_CFLAGS'] = '-Wall -Wextra'
		end

		xcode.XCBuildConfiguration_SwiftLanguageVersion(settings, cfg)

		overrideSettings(settings, cfg.xcodebuildsettings)

		_p(2,'%s /* %s */ = {', cfg.xcode.projectid, cfg.buildcfg)
		_p(3,'isa = XCBuildConfiguration;')
		xcodePrintUserConfigReferences(3, cfg, tr, "project")
		_p(3,'buildSettings = {')
		printSettingsTable(4, settings)
		_p(3,'};')
		printSetting(3, 'name', cfg.buildcfg);
		_p(2,'};')
	end


	function xcode.XCBuildConfiguration(tr)
		local settings = {}

		for _, target in ipairs(tr.products.children) do
			for _, cfg in ipairs(tr.configs) do
				settings[cfg.xcode.targetid] = function()
					xcode.XCBuildConfiguration_Target(tr, target, cfg)
				end
			end
		end
		for _, cfg in ipairs(tr.configs) do
			settings[cfg.xcode.projectid] = function()
				xcode.XCBuildConfiguration_Project(tr, cfg)
			end
		end

		if not table.isempty(settings) then
			_p('/* Begin XCBuildConfiguration section */')
			printSettingsTable(0, settings)
			_p('/* End XCBuildConfiguration section */')
			_p('')
		end
	end


	function xcode.XCBuildConfigurationList(tr)
		local wks = tr.project.workspace
		local defaultCfgName = stringifySetting(tr.configs[1].buildcfg)
		local settings = {}

		for _, target in ipairs(tr.products.children) do
			settings[target.cfgsection] = function()
				_p(2,'%s /* Build configuration list for PBXNativeTarget "%s" */ = {', target.cfgsection, target.name)
				_p(3,'isa = XCConfigurationList;')
				_p(3,'buildConfigurations = (')
				for _, cfg in ipairs(tr.configs) do
					_p(4,'%s /* %s */,', cfg.xcode.targetid, cfg.buildcfg)
				end
				_p(3,');')
				_p(3,'defaultConfigurationIsVisible = 0;')
				_p(3,'defaultConfigurationName = %s;', defaultCfgName)
				_p(2,'};')
			end
		end
		settings['1DEB928908733DD80010E9CD'] = function()
			_p(2,'1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "%s" */ = {', tr.name)
			_p(3,'isa = XCConfigurationList;')
			_p(3,'buildConfigurations = (')
			for _, cfg in ipairs(tr.configs) do
				_p(4,'%s /* %s */,', cfg.xcode.projectid, cfg.buildcfg)
			end
			_p(3,');')
			_p(3,'defaultConfigurationIsVisible = 0;')
			_p(3,'defaultConfigurationName = %s;', defaultCfgName)
			_p(2,'};')
		end

		_p('/* Begin XCConfigurationList section */')
		printSettingsTable(2, settings)
		_p('/* End XCConfigurationList section */')
	end
