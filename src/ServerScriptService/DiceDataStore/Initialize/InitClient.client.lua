--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
	cache[serviceName] = game:GetService(serviceName)
	return cache[serviceName]
end})

--// functions
local Player = Services['Players'].LocalPlayer
if script:IsDescendantOf(Player) then
	local findModule = Services['ReplicatedStorage']:FindFirstChild(script.DataStoreName.Value,true)
	local currentClock = os.clock()
	while not findModule and os.clock() - currentClock < 5 do
		for index,modules in pairs(Services['ReplicatedStorage']:GetDescendants()) do
			if modules.Name == script.DataStoreName.Value then
				findModule = modules
			end
		end
		if findModule then break end
		Services['RunService'].Heartbeat:Wait()
	end
	require(findModule)
end