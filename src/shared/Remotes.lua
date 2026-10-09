--!nonstrict
-- Network surface. The server creates these instances; the client waits for them.
-- Client -> server goes through ONE RemoteFunction ("Request") with a whitelisted action name;
-- server -> client uses the RemoteEvents below. Nothing else is exposed.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.events = { "Sync", "Tick", "Notify", "Announce", "Leaderboards" }
Remotes.functions = { "Request" }

--- Server: create. Client: wait.
function Remotes.get(): { [string]: any }
	local out: { [string]: any } = {}
	local folder: Instance
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, n in ipairs(Remotes.events) do
			local e = Instance.new("RemoteEvent")
			e.Name = n
			e.Parent = folder
			out[n] = e
		end
		for _, n in ipairs(Remotes.functions) do
			local f = Instance.new("RemoteFunction")
			f.Name = n
			f.Parent = folder
			out[n] = f
		end
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
		for _, n in ipairs(Remotes.events) do
			out[n] = folder:WaitForChild(n)
		end
		for _, n in ipairs(Remotes.functions) do
			out[n] = folder:WaitForChild(n)
		end
	end
	return out
end

return Remotes
