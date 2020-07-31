--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// functions
local Initialize = script.Parent
local DataStore = Initialize.Parent
if  DataStore then
	require(DataStore)
	local InitClient = Initialize:WaitForChild('InitClient')
	InitClient.DataStoreName.Value = DataStore.Name
	InitClient.Parent = Services['StarterPlayer']['StarterPlayerScripts']
	InitClient.Disabled = false
	Initialize:Destroy()
end