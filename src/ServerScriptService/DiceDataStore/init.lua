--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: Datastore system that can replace DS2/Roblox Datastore implementation. Roll the dice 🎲
--]]

--[[
[DOCUMENTATION]:
	https://github.com/Mullets-Gavin/DiceDataStore
	Listed below is a quick glance on the API, visit the link above for proper documentation

[PLAYER SERVICE]:
	:SetData()
	:LoadData()
	:SaveData()
	:GetData()
	:UpdateData()
	:IncrementData()
	:RemoveData()
	:WatchData()
	:CalculateSize() 

[GLOBAL SERVICE]:
	:SetGlobals()
	:GetGlobals()
	:UpdateGlobals()

[FEATURES]:
	- Automatic retries (stops at 5)
	- Backups
	- Prevents data over writing saves per session
	- Saves on BindToClose by default, no need to write your own code
	- Super minimal networking with packets
	- Real-time data replication
	- Globals datastore support, meaning you can have a global datastore for your entire game
]]--

--// logic
local DataStore = {}
DataStore.Cache = {}
DataStore.Default = {}
DataStore.Globals = {}
DataStore.Removal = {}
DataStore.LoadedPlayers = {}
DataStore.FlaggedData = {}
DataStore.Shutdown = false
DataStore.RemovePlayerRef = nil;
DataStore.Key = 'mulletmafiadev'
DataStore.GlobalKey = 'mulletmafialogs'
DataStore.INITIALIZED = false

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// public functions
--[[
	Variations of call:
	
	:SetData('key',{})
	:SetData({})
]]--
function DataStore:SetData(dataFile,extraFile)
	if type(dataFile) == 'table' then
		DataStore.Default = dataFile
	elseif tostring(dataFile) then
		DataStore.Key = dataFile
		if type(extraFile) == 'table' then
			DataStore.Default = extraFile
		end
	end
	if Services['RunService']:IsServer() then
		if DataStore['SetDataEvent'] then
			DataStore['SetDataEvent']:Disconnect()
		end
		local function sendCache(Plr)
			repeat wait() until DataStore.LoadedPlayers[Plr.UserId] ~= nil
			DataStore.Network.SendData:FireClient(Plr,'SetData',dataFile,extraFile)
		end
		DataStore['SetDataEvent'] = Services['Players'].PlayerAdded:Connect(function(Plr)
			sendCache(Plr)
		end)
		for index,plrs in pairs(Services['Players']:GetPlayers()) do
			sendCache(plrs)
		end
	elseif Services['RunService']:IsClient() then
		DataStore['Initialized'] = true
	end
end

--[[
	Variations of call:
	
	:SetRemoval({})
]]--
function DataStore:SetRemoval(dataFile)
	if type(dataFile) == 'table' then
		DataStore.Removal = dataFile
	end
end

--[[
	Variations of call:
	
	:SetGlobals('key',{})
	:SetGlobals({})
]]--
function DataStore:SetGlobals(dataFile,extraFile)
	if type(dataFile) == 'table' then
		DataStore.Globals = dataFile
	elseif tostring(dataFile) then
		DataStore.GlobalKey = dataFile
		if type(extraFile) == 'table' then
			DataStore.Globals = extraFile
		end
	end
end

--[[
	Variations of call:
	
	:GetData()
	:GetData(coins)
	:GetData(userID,coins)
	:GetData(userID)
]]--
function DataStore:GetData(dataFile,optFile)
	if Services['RunService']:IsClient() then
		while not DataStore['Initialized'] or not DataStore['Cached'] or not DataStore.LoadedPlayers do Services['RunService'].Heartbeat:Wait() end
		--repeat Services['RunService'].Heartbeat:Wait() until DataStore['Initialized'] and DataStore['Cached'] and DataStore.LoadedPlayers == true
		if not dataFile then -- :GetData()
			local getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId]
			return getFile
		elseif DataStore.Default[dataFile] ~= nil then -- :GetData(coins)
			local getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId]
			return getFile[dataFile]
		elseif tonumber(dataFile) and DataStore.Default[optFile] then -- :GetData(userId,coins)
			local getUserData = DataStore.Network.RetrieveData:InvokeServer('GetData',dataFile,optFile)
			if getUserData then
				return getUserData
			end
		elseif tonumber(dataFile) and not optFile then -- :GetData(userID)
			local getUserData = DataStore.Network.RetrieveData:InvokeServer('GetData',dataFile)
			if getUserData then
				return getUserData
			end
		end
		return false
	elseif Services['RunService']:IsServer() then
		while DataStore.LoadedPlayers[dataFile] == nil and DataStore.Cache[dataFile] == nil do Services['RunService'].Heartbeat:Wait() end
		--repeat Services['RunService'].Heartbeat:Wait() until DataStore.LoadedPlayers[dataFile] ~= nil and DataStore.Cache[dataFile] ~= nil
		if tonumber(dataFile) and DataStore.Default[optFile] ~= nil then -- :GetData(userId,coins)
			local getFile = DataStore.Cache[dataFile]
			if getFile then
				return getFile[optFile]
			end
		elseif tonumber(dataFile) and not optFile then -- :GetData(userID)
			local getFile = DataStore.Cache[dataFile]
			if getFile then
				return getFile
			elseif not getFile then
				return DataStore:LoadData(dataFile)
			end
		end
		return false
	end
end

--[[
	Variations of call:
	
	:GetGlobals()
	:GetGlobals(Bans)
--]]
function DataStore:GetGlobals(dataFile)
	if Services['RunService']:IsClient() then
		if dataFile ~= nil then
			local getUserData,loadFile = DataStore.Network.RetrieveData:InvokeServer('GetGlobals',dataFile)
			if getUserData then
				return getUserData
			end
		else
			local getUserData,loadFile = DataStore.Network.RetrieveData:InvokeServer('GetGlobals')
			if getUserData then
				return getUserData
			end
		end
	elseif Services['RunService']:IsServer() then
		repeat Services['RunService'].Heartbeat:Wait() until DataStore.Methods ~= nil and DataStore.INITIALIZED ~= nil
		local loadFile,globalFile = DataStore.Methods.GlobalData(DataStore.GlobalKey,DataStore.Globals)
		if dataFile ~= nil then
			if DataStore.Globals[dataFile] then
				return globalFile[dataFile],loadFile
			end
		else
			return globalFile,loadFile
		end
	end
	return false
end

--[[
	Variations of call:
	
	:UpdateData(userId,newFile)
	:UpdateData(userId,dataFile,newData)
]]--
function DataStore:UpdateData(userId,dataFile,newData)
	if Services['RunService']:IsServer() then
		local getFile = DataStore.Cache[userId]
		if getFile or newData == 'OVERRIDE' then
			if newData ~= nil and dataFile then
				DataStore.Cache[userId][dataFile] = newData
				getFile = DataStore.Cache[userId][dataFile]
				local Plr = game.Players:GetPlayerByUserId(userId)
				if Plr then
					DataStore.Network.SendData:FireClient(Plr,'UpdateData',userId,dataFile,newData)
				end
				if dataFile and userId and newData ~= nil then
					DataStore.Events.WatchData('Fire',dataFile,userId,newData)
				end
				return getFile,true
			elseif type(dataFile) == 'table' and not newData then
				DataStore.Cache[userId] = dataFile
				getFile = DataStore.Cache[userId]
				local Plr = game.Players:GetPlayerByUserId(userId)
				if Plr then
					DataStore.Network.SendData:FireClient(Plr,'UpdateData',userId,dataFile,newData)
				end
				return getFile,true
			elseif newData == 'OVERRIDE' then
				DataStore.Cache[userId] = dataFile
				getFile = DataStore.Cache[userId]
				return getFile,true
			end
		end
		warn('[DS]:','The player file does not exist and/or you are missing arguments\n> Server |','Value:',dataFile,'|',newData)
	elseif Services['RunService']:IsClient() then
		local getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId]
		if getFile then
			if newData ~= nil and dataFile then
				DataStore.Cache[Services['Players'].LocalPlayer.UserId][dataFile] = newData
				getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId][dataFile]
				if dataFile and userId and newData ~= nil then
					DataStore.Events.WatchData('Fire',dataFile,newData)
				end
				return getFile,true
			elseif type(dataFile) == 'table' and not newData then
				DataStore.Cache[Services['Players'].LocalPlayer.UserId] = dataFile
				getFile = dataFile
				return getFile,true
			elseif newData == 'OVERRIDE' then
				DataStore.Cache[Services['Players'].LocalPlayer.UserId] = dataFile
				getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId]
				return getFile,true
			end
		elseif type(dataFile) == 'table' then -- assume its never been cached
			DataStore.Cache[Services['Players'].LocalPlayer.UserId] = dataFile
			getFile = DataStore.Cache[Services['Players'].LocalPlayer.UserId]
			if not DataStore['Cached'] then
				DataStore['Cached'] = true
			end
			return getFile,true
		end
		warn('[DS]:','The player file does not exist and/or you are missing arguments\n> Client |','Value:',dataFile,'|',newData)
	end
	return false
end

--[[
	Variations of call:
	
	:UpdateGlobals(dataFile,newData)
	:UpdateGlobals(dataFile)
]]--
function DataStore:UpdateGlobals(dataFile,newData)
	if Services['RunService']:IsServer() then
		if newData ~= nil and dataFile then
			DataStore.Globals[dataFile] = newData
			local updatedFile,didSave = DataStore.Methods.SaveData(DataStore.GlobalKey,DataStore.Globals,DataStore.GlobalKey,'OVERRIDE')
			if didSave then
				print('[DS]: Updated & Saved Globals | File size:',#Services['HttpService']:JSONEncode(DataStore.Globals),'bytes')
			end
			return DataStore.Globals[dataFile],true
		elseif dataFile and not newData then
			DataStore.Globals = dataFile
			local updatedFile,didSave = DataStore.Methods.SaveData(DataStore.GlobalKey,DataStore.Globals,DataStore.GlobalKey,'OVERRIDE')
			if didSave then
				print('[DS]: Updated & Saved Globals | File size:',#Services['HttpService']:JSONEncode(DataStore.Globals),'bytes')
			end
			return DataStore.Globals,true
		end
	end
	return false
end

--[[
	Variations of call:
	
	:IncrementData(userId,'coins',5)
	:IncrementData(userId,'coins',-5)
]]--
function DataStore:IncrementData(userId,dataFile,newData)
	coroutine.wrap(function()
		if Services['RunService']:IsClient() then return DataStore:GetData(userId) end
		local currentAmt = DataStore:GetData(userId,dataFile)
		if currentAmt and tonumber(newData) then
			currentAmt = currentAmt + newData
			local newAmt = DataStore:UpdateData(userId,dataFile,currentAmt)
			return newAmt
		end
		return false
	end)()
end

--[[
	Variations of call:
	
	:WatchData(data,userId,function) -- SERVER ONLY
	:WatchData(data,function) -- CLIENT ONLY
]]--
function DataStore:WatchData(dataFile,valueFile,extraFile)
	assert(type(dataFile) == 'string','To watch data, use a valid Key')
	if type(valueFile) == 'function' and Services['RunService']:IsClient() then
		if DataStore:GetData(dataFile) then
			DataStore.Events.WatchData('Create',dataFile,valueFile)
			return true
		end
	elseif type(valueFile) == 'number' and Services['RunService']:IsServer() then
		if DataStore:GetData(valueFile,dataFile) then
			DataStore.Events.WatchData('Create',dataFile,valueFile,extraFile)
			return true
		end
	end
	return false
end

--[[
	Variations of call:
	
	:LoadData(userId)
	:LoadData(userId,true)
	
	Returns:
	true/false, data
]]--
function DataStore:LoadData(userId,autoSave)
	if Services['RunService']:IsClient() then return DataStore:GetData(userId) end
	while DataStore.Cache[userId] do Services['RunService'].Heartbeat:Wait() end
	local loadFile,plrFile = DataStore.Methods.LoadData(userId,DataStore.Default,DataStore.Key)
	if autoSave then
		coroutine.wrap(function()
			while Services['Players']:GetPlayerByUserId(userId) do
				wait(300)
				if DataStore.Cache[userId] then
					DataStore:SaveData(userId)
					DataStore:CalculateSize(userId,true)
				end
			end
		end)()
	end
	if plrFile['Loaded'] then
		DataStore.Cache[userId] = plrFile
		DataStore:CalculateSize(userId)
		local Plr = Services['Players']:GetPlayerByUserId(userId)
		pcall(function() if Plr then DataStore.Network.RetrieveData:InvokeClient(Plr,'UpdateData',userId,plrFile) end end)
		return plrFile,loadFile
	end
	return false,false
end

--[[
	Variations of call:
	
	:SaveData(userId,removeAfter)
	
	Returns:
	true or false
]]--
function DataStore:SaveData(userId,removeAfter,override)
	if DataStore.Shutdown and not override then return end
	if Services['RunService']:IsClient() then return DataStore:GetData(userId) end
	if not DataStore.Cache[userId] ~= nil and not override == 'PERM' then return end
	local getFile = DataStore.Cache[userId]
	if override ~= 'PERM' and getFile ~= nil then
		for index,key in pairs(DataStore.Removal) do
			if DataStore.Default[key] ~= nil then
				DataStore:UpdateData(userId,key,DataStore.Default[key])
			end
		end
	end
	local loadFile,plrFile = DataStore.Methods.SaveData(userId,getFile,DataStore.Key,removeAfter,override)
	if removeAfter == true then
		DataStore.LoadedPlayers[userId] = nil
		DataStore.Cache[userId] = nil
	end
	return plrFile,loadFile
end

--[[
	Variations of call:
	
	:RemoveData(userId)
]]--
function DataStore:RemoveData(userId,all)
	if DataStore.Cache[userId] then
		DataStore:UpdateData(userId,nil,'OVERRIDE')
		if all then
			DataStore:SaveData(userId,'OVERRIDE','PERM')
		else
			DataStore:SaveData(userId,'OVERRIDE')
		end
		local Plr = Services['Players']:GetPlayerByUserId(userId)
		pcall(function() if Plr then DataStore.Network.RetrieveData:InvokeClient(Plr,'UpdateData',userId,nil,'OVERRIDE') end end)
		DataStore.Cache[userId] = nil
	else
		DataStore:UpdateData(userId,nil,'OVERRIDE')
		if all then
			DataStore:SaveData(userId,'OVERRIDE','PERM')
		else
			DataStore:SaveData(userId,'OVERRIDE')
		end
	end
end

--[[
	Variations of call:
	
	:CalculateSize(userId)
]]--
function DataStore:CalculateSize(userId,autoSave)
	if DataStore.Cache[userId] then
		local getPlrName
		local success,err = pcall(function()
			getPlrName = Services['Players']:GetNameFromUserIdAsync(userId)
		end)
		if not success then
			getPlrName = 'Player'
		end
		if not autoSave then
			print('[DS]:',getPlrName..' ('..userId..')','|','File size:',#Services['HttpService']:JSONEncode(DataStore.Cache[userId])..' bytes')
		else
			print('[DS]:',getPlrName..' ('..userId..')','|','File size:',#Services['HttpService']:JSONEncode(DataStore.Cache[userId])..' bytes','|','Auto saved data')
		end
	end
end

--[[
	Initialize the module
]]--
local function SearchDataModel(moduleName)
	if Services['RunService']:IsServer() then
		for index,modules in pairs(Services['ServerScriptService']:GetDescendants()) do
			if modules.Name == moduleName then
				return true
			end
		end
	end
	for index,modules in pairs(Services['ReplicatedStorage']:GetDescendants()) do
		if modules.Name == moduleName then
			return true
		end
	end
	return false
end

coroutine.wrap(function()
	if not DataStore.INITIALIZED then
		DataStore.INITIALIZED = true
		local Source = script.Parent
		local findEvents = script:FindFirstChild('Events')
		local findMethods = script:FindFirstChild('Methods')
		if findMethods then
			findMethods.Parent = Services['ServerScriptService']
			if SearchDataModel('PlayingCards') then
				local loadPlayingCards = Services['ReplicatedStorage']:WaitForChild('PlayingCards')
				local findDeckClient = loadPlayingCards:FindFirstChild('DeckClient')
				if findDeckClient then
					script.Parent = findDeckClient
				end
			else
				script.Parent = Services['ReplicatedStorage']
			end
		end
		if Services['RunService']:IsServer() and not DataStore.Methods then
			DataStore.Methods = require(findMethods)
		end
		if not DataStore.Events then
			DataStore.Events = require(findEvents)
		end
		local findNetwork = script:FindFirstChild('Network')
		if findNetwork and not DataStore.Network then
			DataStore.Network = findNetwork
		end
	end
	
	if Services['RunService']:IsServer() then
		game:BindToClose(function()
			print('[DS]: Shutting down and saving player data')
			if Services['RunService']:IsStudio() then return end
			DataStore.Shutdown = true
			for index,plrs in pairs(Services['Players']:GetPlayers()) do
				DataStore:SaveData(plrs.UserId,true,true)
			end
			wait(5)
		end)
		DataStore.Network.RetrieveData.OnServerInvoke = function(plrClient,toCall,dataFile,optFile)
			if toCall == 'GetData' then
				return DataStore:GetData(dataFile,optFile)
			elseif toCall == 'GetGlobals' then
				return DataStore:GetGlobals(dataFile)
			end
		end
		DataStore.Network.SendData.OnServerEvent:Connect(function(plr,cmd)
			if cmd == 'Loaded' then
				if DataStore.LoadedPlayers[plr.UserId] == nil then
					DataStore.LoadedPlayers[plr.UserId] = true
				end
			end
		end)
	elseif Services['RunService']:IsClient() then
		DataStore.Network.RetrieveData.OnClientInvoke = function(toCall,dataFile,optFile,extraFile)
			if toCall == 'UpdateData' then
				DataStore:UpdateData(dataFile,optFile,extraFile)
				return true
			end
		end
		DataStore.Network.SendData.OnClientEvent:Connect(function(cmd,dataFile,optFile,extraFile)
			if cmd == 'SetData' then
				DataStore:SetData(dataFile,optFile)
			elseif cmd == 'UpdateData' then
				DataStore:UpdateData(dataFile,optFile,extraFile)
				return true
			end
		end)
		DataStore.LoadedPlayers = true
		DataStore.Network.SendData:FireServer('Loaded')
	end
end)()

return DataStore