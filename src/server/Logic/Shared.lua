--!strict
-- Single place where server code reaches the shared (ReplicatedStorage) modules.
-- tools/stage_tests.py replaces this file with a flat-require stub for out-of-Roblox unit tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

return {
	Config = require(Shared:WaitForChild("Config")),
	Creatures = require(Shared:WaitForChild("Creatures")),
	Machines = require(Shared:WaitForChild("Machines")),
	Research = require(Shared:WaitForChild("Research")),
	Prestige = require(Shared:WaitForChild("Prestige")),
	Quests = require(Shared:WaitForChild("Quests")),
	Formulas = require(Shared:WaitForChild("Formulas")),
	Stats = require(Shared:WaitForChild("Stats")),
	Monetization = require(Shared:WaitForChild("Monetization")),
}
