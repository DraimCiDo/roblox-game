--!nocheck
-- Checks that every require() of a script path or a ReplicatedStorage.Shared path points at a ModuleScript.
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

local checked, broken = 0, 0
for _, root in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" } do
	for _, instance in dataModel:GetService(root):GetDescendants() do
		if instance:IsA("LuaSourceContainer") then
			for expression in string.gmatch(instance.Source, "require%(([%a_][%w_%.]*)%)") do
				checked += 1
				local target = resolve(instance, expression)
				if not target or not target:IsA("ModuleScript") then
					broken += 1
					print(`{instance:GetFullName()}: require({expression}) does not resolve`)
				end
			end
		end
	end
end

if broken > 0 then
	print(`requires FAILED: {broken} of {checked}`)
	process.exit(1)
end
print(`requires OK: {checked}`)
