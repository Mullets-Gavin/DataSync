--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// functions
local Player = Services['Players'].LocalPlayer
if script:IsDescendantOf(Player) then
	for index,modules in pairs(Services['ReplicatedStorage']:GetDescendants()) do
		if modules.Name == script.DataStoreName.Value then
			require(modules)
		end
	end
	Services['RunService'].Heartbeat:Wait()
	script:Destroy()
end