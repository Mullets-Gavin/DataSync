--// logic
local Events = {}
Events.Connections = {}

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// functions
function Events.WatchData(act,dataFile,valueFile,extraFile)
	if act == 'Create' then
		if Services['RunService']:IsClient() then
			local format = {
				['Key'] = dataFile;
				['Function'] = valueFile;
			}
			table.insert(Events.Connections,format)
		elseif Services['RunService']:IsServer() then
			if not Events.Connections[valueFile] then
				Events.Connections[valueFile] = {}
			end
			local format = {
				['Key'] = dataFile;
				['UserId'] = valueFile;
				['Function'] = extraFile;
			}
			table.insert(Events.Connections[valueFile],format)
		end
	elseif act == 'Fire' then
		if Services['RunService']:IsClient() then
			for index,file in ipairs(Events.Connections) do
				coroutine.wrap(function()
					if file['Key'] == dataFile then
						file['Function'](valueFile)
					end
				end)()
			end
		elseif Services['RunService']:IsServer() then
			if Events.Connections[valueFile] then
				for index,file in ipairs(Events.Connections[valueFile]) do
					coroutine.wrap(function()
						if file['Key'] == dataFile then
							file['Function'](extraFile)
						end
					end)()
				end
			end
		end
	end
end

return Events