--!nocheck
-- Static link check: every require() of a script or ReplicatedStorage.Shared path points at a ModuleScript,
-- and every Module.member used through such a local is declared somewhere in that module.
--   lune run tests/requires.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local BUILD = "build/requires.rbxl"
fs.writeDir("build")
local built = process.exec("rojo", { "build", "default.project.json", "-o", BUILD })
assert(built.ok, built.stderr)
local dataModel = roblox.deserializePlace(fs.readFile(BUILD))

local function resolve(script, expression: string)
	local names = string.split(expression, ".")
	local head = table.remove(names, 1)
	local node
	if head == "script" then
		node = script
	elseif head == "ReplicatedStorage" then
		node = dataModel:GetService("ReplicatedStorage")
	else
		-- A local alias such as `Config`: resolve the alias first.
		local alias = string.match(script.Source, "\nlocal " .. head .. " = (script[%w_%.]*)\n")
		node = alias and resolve(script, alias)
	end
	for _, name in names do
		if not node then
			return nil
		end
		node = if name == "Parent" then node.Parent else node:FindFirstChild(name)
	end
	return node
end

-- A member counts as declared if the module has it as a function, assigned field, table key or type.
local function declares(source: string, name: string): boolean
	local text = "\n" .. source
	local word = name .. "%f[^%w_]"
	return string.find(text, "function [%w_]+[%.:]" .. word) ~= nil
		or string.find(text, "\n[%w_]+%." .. word .. "[^\n=]*=") ~= nil
		or string.find(text, "\n\t" .. name .. "%s*=") ~= nil
		or string.find(text, "type " .. word) ~= nil
end

local checked, members, broken = 0, 0, 0

local function report(message: string)
	broken += 1
	print(message)
end

for _, root in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	for _, instance in dataModel:GetService(root):GetDescendants() do
		if not instance:IsA("LuaSourceContainer") then
			continue
		end
		-- Comments are dropped so that file names such as "Sector.luau" are not read as member uses.
		local source = "\n" .. string.gsub(instance.Source, "%-%-[^\n]*", "")
		for expression in string.gmatch(source, "require%(([%a_][%w_%.]*)%)") do
			checked += 1
			local target = resolve(instance, expression)
			if not target or not target:IsA("ModuleScript") then
				report(`{instance:GetFullName()}: require({expression}) does not resolve`)
			end
		end
		for alias, expression in string.gmatch(source, "\nlocal ([%a_][%w_]*) = require%(([%a_][%w_%.]*)%)") do
			local target = resolve(instance, expression)
			if not target then
				continue
			end
			for name in string.gmatch(source, "%f[%w_%.:]" .. alias .. "[%.:]([%a_][%w_]*)") do
				members += 1
				if not declares(target.Source, name) then
					report(`{instance:GetFullName()}: {alias}.{name} is not declared in {target.Name}`)
				end
			end
		end
	end
end

if broken > 0 then
	print(`requires FAILED: {broken} problems`)
	process.exit(1)
end
print(`requires OK: {checked} paths, {members} member uses`)
