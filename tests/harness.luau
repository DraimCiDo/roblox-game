--!nocheck
-- Loads game ModuleScripts under Lune from a Rojo build, so pure logic can be exercised without Studio.
-- Random and GUID generation are replaced with deterministic fakes.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local BUILD = "build/test.rbxl"

local Harness = {}

fs.writeDir("build")
local built = process.exec("rojo", { "build", "default.project.json", "-o", BUILD })
assert(built.ok, built.stderr)
local dataModel = roblox.deserializePlace(fs.readFile(BUILD))

local seed = 1

local function nextUnit(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

function Harness.reseed(value: number)
	seed = value
end

local fakeRandom = {
	new = function()
		return {
			NextNumber = function(_, low: number?, high: number?)
				local unit = nextUnit()
				return if low then low + (high - low) * unit else unit
			end,
			NextInteger = function(_, low: number, high: number)
				return low + math.floor(nextUnit() * (high - low + 1))
			end,
		}
	end,
}

local guid = 0
local fakeHttp = {
	GenerateGUID = function()
		guid += 1
		return `guid-{guid}`
	end,
}

local fakeGame = {
	GetService = function(_, name: string)
		if name == "HttpService" then
			return fakeHttp
		end
		return dataModel:GetService(name)
	end,
}

local cache: { [any]: any } = {}

local function load(module): any
	local path = module:GetFullName()
	if cache[path] == nil then
		local chunk = luau.load(module.Source, {
			debugName = path,
			environment = {
				game = fakeGame,
				script = module,
				require = load,
				Random = fakeRandom,
				Color3 = roblox.Color3,
				Vector3 = roblox.Vector3,
				Font = roblox.Font,
				Enum = roblox.Enum,
			},
		})
		cache[path] = chunk()
	end
	return cache[path]
end

-- Finds a ModuleScript by its dotted path below a service, e.g. "ReplicatedStorage.Shared.Config.Catalog".
function Harness.require(path: string): any
	local names = string.split(path, ".")
	local node = dataModel:GetService(table.remove(names, 1))
	for _, name in names do
		node = assert(node:FindFirstChild(name), `module not found: {path}`)
	end
	return load(node)
end

return Harness
