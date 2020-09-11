--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: Datastore system that can replace DS2/Roblox Datastore implementation. Roll the dice 🎲
	@Note: While developing the rework, I didn't know what I was doing so all parameters are laid out in dictionary format
--]]

--[[
[DOCUMENTATION]:
	https://github.com/Mullets-Gavin/DiceDataStore
	Listed below is a quick glance on the API, visit the link above for proper documentation

[METHODS]:
	:SetData()
	:LoadData()
	:SaveData()
	:GetData()
	:UpdateData()
	:IncrementData()
	:RemoveData()
	:WatchData()
	:CalculateSize() 

[FEATURES]:
	- Automatic retries (stops at 5)
	- Prevents data over writing saves per session
	- Saves on BindToClose by default, no need to write your own code
	- Super minimal networking with packets
	- Real-time data replication
]]--

--// logic
local DataStore = {}
DataStore.Shutdown = false
DataStore.Initialized = false
DataStore.LoadedPlayers = {}
DataStore.FlaggedData = {}

local Configuration = {}
Configuration.Key = nil
Configuration.Cached = {}
Configuration.Removal = {}
Configuration.Files = {}
Configuration.Internal = {
	['Set'] = 'SetData';
	['Get'] = 'GetData';
	['Load'] = 'LoadData';
	['Save'] = 'SaveData';
	['Spawn'] = 'SpawnData';
	['Watch'] = 'WatchData';
	['Update'] = 'UpdateData';
	['Increment'] = 'IncrementData';
}

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
	cache[serviceName] = game:GetService(serviceName)
	return cache[serviceName]
end})

--// variables
local Player = Services['Players'].LocalPlayer

local Modules = script:WaitForChild('Modules')
local MsgService = require(Modules:WaitForChild('MsgService'))
local Manager = require(Modules:WaitForChild('Manager'))
local Methods = require(Modules:WaitForChild('Methods'))

local Network = script:WaitForChild('Network')
local NetSend = Network.SendData
local NetRetrieve = Network.RetrieveData

local IsStudio = Services['RunService']:IsStudio()
local IsServer = Services['RunService']:IsServer()
local IsClient = Services['RunService']:IsClient()

--// functions
local function Send(...)
	local data = {...}
	if IsServer then
		if typeof(data[1]) == 'Instance' and data[1]:IsA('Player') then -- to player
			local plr = data[1]
			local topic = data[2]
			table.remove(data,table.find(data,plr))
			table.remove(data,table.find(data,topic))
			NetSend:FireClient(plr,topic,table.unpack(data))
			return true
		end
		local topic = data[1]
		table.remove(data,table.find(data,topic))
		NetSend:FireAllClients(topic,table.unpack(data))
		return true
	end
	local topic = data[1]
	table.remove(data,table.find(data,topic))
	NetSend:FireServer(topic,table.unpack(data))
	return true
end

local function Retrieve(...)
	local data = {...}
	if IsServer then
		if typeof(data[1]) == 'Instance' and data[1]:IsA('Player') then -- to player
			local results = nil
			local plr = data[1]
			local topic = data[2]
			table.remove(data,table.find(data,plr))
			table.remove(data,table.find(data,topic))
			local success,err = pcall(function()
				results = NetRetrieve:InvokeClient(plr,topic,table.unpack(data))
			end)
			if success then
				return results
			end
			return false
		end
		return false
	end
	local topic = data[1]
	table.remove(data,table.find(data,topic))
	local results = NetSend:InvokeServer(topic,table.unpack(data))
	return results
end

local function GetPlayer(userID)
	local plr = nil
	local success,err = pcall(function()
		plr = Services['Players']:GetPlayerByUserId(userID)
	end)
	if not success then return false end
	return plr
end

--[[
	Variations of call:
	
	:SetData('key',{})
	:SetData('key',{},true)
]]--
function DataStore:SetData(...)
	local data = {...}
	local key = data[1]
	local value = data[2]
	local sync = data[3] or false
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(typeof(value) == 'table',"[DICE DATASTORE]: Data 'table' or 'dictionary' expected, got '".. typeof(key) .."'")
	
	if Configuration.Files[key] ~= nil then
		if Configuration.Files[key]['Event'] then
			Configuration.Files[key]['Event']:Disconnect()
		end
		if Configuration.Files[key]['Task'] then
			Configuration.Files[key]['Task']:Disconnect()
		end
		Configuration.Files[key] = nil
	end
	
	value['___PlayingCards'] = false
	Methods.SetDefault(key,value)
	Configuration.Files[key] = {
		['Default'] = value;
		['Cache'] = {};
		['Tasks'] = {};
		['Event'] = nil;
		['Sync'] = sync;
	}
	
	if sync and not Configuration.Key then
		Configuration.Key = key
	end
	
	if sync and IsServer then
		local function SendCache(plr)
			while not DataStore.LoadedPlayers[plr.UserId] do Services['RunService'].Heartbeat:Wait() end
			Send(plr, Configuration.Internal.Set, key, Configuration.Files[key], sync)
		end
		
		Configuration.Files[key]['Event'] = Services['Players'].PlayerAdded:Connect(function(plr)
			SendCache(plr)
		end)
		for index,plr in pairs(Services['Players']:GetPlayers()) do
			SendCache(plr)
		end
	elseif IsClient then
		DataStore.Initialized = true
	end
end

--[[
	Variations of call:
	
	:SetRemoval({})
]]--
function DataStore:SetRemoval(...)
	local data = {...}
	local key = data[1]
	local value = data[2]
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(typeof(value) == 'table',"[DICE DATASTORE]: Data 'table' or 'dictionary' expected, got '".. typeof(key) .."'")
	Configuration.Removal[key] = value
end

--[[
	Variations of call:
	
	:GetData()
	:GetData(coins)
	:GetData(userID,coins)
	:GetData(userID)
	
	:GetData() -- Config.Key, LocalPlayer.UserId
	Returns entire default table
	
	:GetData(value) -- Config.Key, LocalPlayer.UserId, value
	Returns value from default table with player id as key
	
	:GetData(index,value) -- Config.Key, index, value
	Returns value from default table
	
	:GetData(key,index) -- key, index
	Returns entire table
	
	:GetData(key,index,value) -- key, index, value
	Returns value from table
]]--
function DataStore:GetData(...)
	local data = {...}
	local key = data[1]
	local index = data[2]
	local value = data[3]
	local plr = nil
	local task = nil
		
	local control = {}
	control.__Return = nil
	control.__Update = function()
		if IsClient then
			if tonumber(index) ~= Player.UserId and Configuration.Key == key and plr then
				local get = Retrieve(plr, Configuration.Internal.Get, key, index, value)
				control.__Return = get
				task:Pause()
				return
			end
		end
		if value == nil then
			control.__Return = Configuration.Files[key]['Cache'][index]
			task:Pause()
			return
		elseif value ~= nil then
			control.__Return = Configuration.Files[key]['Cache'][index][value]
			task:Pause()
			return
		end
		warn("[DICE DATASTORE]: Could not find data, key '",key,"' and index '",index,"' and '",value,"'")
		control.__Return = false
		task:Pause()
		return
	end
	
	plr = GetPlayer(key)
	if not plr then
		plr = GetPlayer(index)
	end
	while Configuration.Key == nil do Services['RunService'].Heartbeat:Wait() end
	if key ~= nil and not index and not value and IsClient then
		value = key
		index = Player.UserId
		key = Configuration.Key
	elseif tonumber(key) and key ~= Configuration.Key and index ~= nil then
		value = index
		index = tonumber(key)
		key = Configuration.Key
		if not Player then
			while DataStore.LoadedPlayers[index] == nil do Services['RunService'].Heartbeat:Wait() end
		elseif Player.UserId == tonumber(key) then
			while DataStore.LoadedPlayers[index] == nil do Services['RunService'].Heartbeat:Wait() end
		end
	end
	
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	while Configuration.Files[key] == nil do Services['RunService'].Heartbeat:Wait() end
	while Configuration.Files[key]['Cache'][index] == nil do Services['RunService'].Heartbeat:Wait() end
	task = Configuration.Files[key]['Tasks'][index]
	if not task then
		Configuration.Files[key]['Tasks'][index] = Manager:Task(60)
		task = Configuration.Files[key]['Tasks'][index]
	end
	task:Queue(control.__Update)
	task:Resume()
	return control.__Return
end

--[[
	Variations of call:
	
	:UpdateData(userId,newFile)
	:UpdateData(userId,dataFile,newData)
]]--
function DataStore:UpdateData(...)
	local data = {...}
	local key = data[1]
	local index = data[2]
	local value = data[3]
	local change = data[4]
	local plr = nil
	local task = nil
	
	local control = {}
	control.__Return = nil
	control.__Update = function()
		if typeof(value) == 'table' or value == nil then
			Configuration.Files[key]['Cache'][index] = value
			if plr and IsServer then
				Manager.spawn(function()
					Send(plr, Configuration.Internal.Update, key, index, value)
				end)
			end
			control.__Return = value
			local parse = key..':'..index..':{}'
			Manager:FireKey(parse,value)
			task:Pause()
			return
		elseif value ~= nil then
			Configuration.Files[key]['Cache'][index][value] = change
			if plr and IsServer then
				Manager.spawn(function()
					Send(plr, Configuration.Internal.Update, key, index, value, change)
				end)
			end
			control.__Return = change
			local parse = key..':'..index..':'..value
			Manager:FireKey(parse,change)
			task:Pause()
			return
		end
		warn("[DICE DATASTORE]: Could not find data, key '",key,"' and index '",index,"' and '",value,"'")
		control.__Return = false
		task:Pause()
		return
	end
	
	plr = GetPlayer(key)
	if not plr then
		plr = GetPlayer(index)
	end
	if tonumber(key) and key ~= Configuration.Key then
		change = value
		value = index
		index = tonumber(key)
		key = Configuration.Key
		while DataStore.LoadedPlayers[index] == nil do Services['RunService'].Heartbeat:Wait() end
	end
	
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	while Configuration.Files[key] == nil do Services['RunService'].Heartbeat:Wait() end
	task = Configuration.Files[key]['Tasks'][index]
	if not task then
		Configuration.Files[key]['Tasks'][index] = Manager:Task(60)
		task = Configuration.Files[key]['Tasks'][index]
	end
	task:Queue(control.__Update)
	task:Resume()
	return control.__Return
end

--[[
	Variations of call:
	
	:IncrementData(userId,'coins',5)
	:IncrementData(userId,'coins',-5)
]]--
function DataStore:IncrementData(...)
	local data = {...}
	local key = data[1]
	local index = data[2]
	local value = data[3]
	local change = data[4]
	
	while Configuration.Key == nil do Services['RunService'].Heartbeat:Wait() end
	if tonumber(key) and key ~= Configuration.Key and index ~= nil then
		change = value
		value = index
		index = tonumber(key)
		key = Configuration.Key
		while DataStore.LoadedPlayers[index] == nil do Services['RunService'].Heartbeat:Wait() end
	end
	
	local current = DataStore:GetData(key,index,value)
	if current and tonumber(change) then
		current = current + tonumber(change)
		return DataStore:UpdateData(key,index,value,current)
	end
	return false
end

--[[
	Variations of call:
	
	:WatchData(data,userId,function) -- SERVER ONLY
	:WatchData(data,function) -- CLIENT ONLY
	
	:WatchData(key,index,value,function)
	:WatchData(index,value,function)
	:WatchData(value,function)
]]--
function DataStore:WatchData(...)
	local data = {...}
	local key = data[1]
	local index = data[2]
	local value = data[3]
	local func = data[4]
	
	while not Configuration.Key do Services['RunService'].Heartbeat:Wait() end
	if key ~= nil and index == nil and value == nil and func == nil and IsClient then
		func = key
		value = '{}'
		index = Player.UserId
		key = Configuration.Key
	elseif key ~= nil and index ~= nil and value == nil and func == nil then
		func = index
		value = key
		key = Configuration.Key
		index = Player.UserId
	elseif tonumber(key) and index ~= nil and value == nil and func == nil then
		func = index
		value = '{}'
		index = tonumber(key)
		key = Configuration.Key
	elseif tonumber(key) and index ~= nil and value ~= nil and func == nil then
		func = value
		value = index
		index = tonumber(key)
		key = Configuration.Key
	end
	
	assert(key ~= nil)
	assert(index ~= nil)
	assert(value ~= nil)
	assert(typeof(func) == 'function')
	local parse = key..':'..index..':'..value
	Manager:ConnectKey(parse,func)
end

--[[
	Variations of call:
	
	:LoadData(userId)
	:LoadData(userId,true)
	
	Returns:
	true/false, data
]]--
function DataStore:LoadData(...)
	if IsClient then return end
	local data = {...}
	local key = data[1]
	local index = data[2]
	local auto = data[3] or false
	local plr = nil
	
	if tonumber(key) and key ~= Configuration.Key then
		pcall(function()
			plr = Services['Players']:GetPlayerByUserId(key)
		end)
		auto = index
		index = key
		key = Configuration.Key
	else
		assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
		assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	end
	
	if not Configuration.Files[key] then
		warn("[DICE DATASTORE]: Failed to save data, key expected, got '",typeof(key),"'")
		return false
	end
	
	local success,results = false,false
	local function Load()
		if not table.find(DataStore.FlaggedData,index) then
			table.insert(DataStore.FlaggedData,index)
			local goal = os.clock() + 6
			Manager.spawn(function()
				while os.clock() < goal do
					Services['RunService'].Heartbeat:Wait()
				end
				table.remove(DataStore.FlaggedData,table.find(DataStore.FlaggedData,index))
				if auto then
					while Configuration.Files[key]['Cache'][index] do
						Services['RunService'].Heartbeat:Wait()
						Manager.wait(300)
						DataStore:SaveData(key,index)
					end
				end
			end)
			results,success = Methods:Load(key,index)
			Configuration.Files[key]['Cache'][index] = results
			if plr then
				Manager.wrap(function()
					DataStore:UpdateData(key,index,results)
				end)
			end
			DataStore:CalculateSize(key,index,'Loaded data')
		end
		return success
	end
	
	local task = Configuration.Files[key]['Tasks'][index]
	if not task then
		task = Manager:Task(60)
		Configuration.Files[key]['Tasks'][index] = task
	end
	task:Queue(Load)
	Configuration.Files[key]['Cache'][index] = results
	return success
end

--[[
	Variations of call:
	
	:SaveData(userId,removeAfter)
	:SaveData(key,index,remove)
	
	Returns:
	true or false
]]--
function DataStore:SaveData(...)
	if IsClient then return end
	local data = {...}
	local key = data[1]
	local index = data[2]
	local remove = data[3] or false
	local flag = true
	
	if DataStore.Shutdown and remove then return end
	if tonumber(key) and key ~= Configuration.Key then
		remove = index
		index = key
		key = Configuration.Key
		flag = false
	end
	if flag then
		assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
		assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	end
		
	if DataStore.Shutdown then
		remove = true
	end
	
	if not Configuration.Files[key] then
		warn("[DICE DATASTORE]: Failed to save data, key expected, got '",typeof(key),"'")
		return false
	end
	
	local results = false
	local function Save()
		if not table.find(DataStore.FlaggedData,index) then
			table.insert(DataStore.FlaggedData,index)
			local goal = os.clock() + 6
			local value = Configuration.Files[key]['Cache'][index]
			Manager.spawn(function()
				while os.clock() < goal do
					Services['RunService'].Heartbeat:Wait()
				end
				if remove then
					value['___PlayingCards'] = false
					Configuration.Files[key]['Tasks'][index]:Disconnect()
					Configuration.Files[key]['Tasks'][index] = nil
					Configuration.Files[key]['Cache'][index] = nil
				end
				table.remove(DataStore.FlaggedData,table.find(DataStore.FlaggedData,index))
			end)
			for index,stat in pairs(Configuration.Removal[key]) do
				value[stat] = Configuration.Files[key]['Default'][stat]
			end
			results = Methods:Save(key,index,value)
			if not DataStore.Shutdown then
				DataStore:CalculateSize(key,index,'Saved data')
			end
		end
		return results
	end
	
	local task = Configuration.Files[key]['Tasks'][index]
	if task then
		task:Queue(Save)
		Services['RunService'].Heartbeat:Wait()
		return results
	end
	return Save()
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
	
	Returns:
	success state
]]--
function DataStore:CalculateSize(key,index,suffix)
	if suffix then
		suffix = '| '.. suffix
	else
		suffix = ''
	end
	
	if Configuration.Files[key] then
		local value = Configuration.Files[key]['Cache'][index]
		if value then
			local getPlrName
			local success,err = pcall(function()
				getPlrName = Services['Players']:GetNameFromUserIdAsync(index)
			end)
			if success then
				print('[DICE DATASTORE]:',getPlrName..' ('..index..')','|','File size:',#Services['HttpService']:JSONEncode(value)..' bytes',suffix)
				return true
			end
			print('[DICE DATASTORE]:',key..'['..index..']','|','File size:',#Services['HttpService']:JSONEncode(value)..' bytes',suffix)
			return true
		else
			print('[DICE DATASTORE]:',key,'|','File size:',#Services['HttpService']:JSONEncode(Configuration.Files[key]['Cache'])..' bytes',suffix)
			return true
		end
	end
	return false
end

--// initialize
Manager.wrap(function()
	if not DataStore.Initialized then
		DataStore.Initialized = true
		Manager.spawn(function()
			local currentClock = os.clock()
			while not _G.YieldForDeck and os.clock() - currentClock < 1 do Services['RunService'].Heartbeat:Wait() end
			if not _G.YieldForDeck then
				script.Parent = Services['ReplicatedStorage']
			end
		end)
	end
	
	if IsServer then
		game:BindToClose(function()
			DataStore.Shutdown = true
			print('[DICE DATASTORE]: Shutting down and saving player data')
			local ShutdownTask = Manager:Task(60)
			for index,content in pairs(Configuration.Files[Configuration.Key]['Cache']) do
				ShutdownTask:Queue(Manager.wrap(function()
					local results = DataStore:SaveData(Configuration.Key,index,false)
					if IsStudio then
						DataStore:CalculateSize(Configuration.Key,index,'Shutdown: Saved data')
					end
				end))
			end
			ShutdownTask:Wait()
			Manager.wait(1)
		end)
		NetRetrieve.OnServerInvoke = function(plr,topic,...)
			local data = {...}
			if topic == Configuration.Internal.Get then
				return DataStore:GetData(table.unpack(data))
			end
		end
		NetSend.OnServerEvent:Connect(function(plr,topic,...)
			local data = {...}
			if topic == Configuration.Internal.Spawn then
				DataStore.LoadedPlayers[plr.UserId] = true
			end
		end)
	elseif IsClient then
		NetRetrieve.OnClientInvoke = function(topic,...)
			local data = {...}
			if topic == Configuration.Internal.Update then
				DataStore:UpdateData(table.unpack(data))
				return true
			end
		end
		NetSend.OnClientEvent:Connect(function(topic,...)
			local data = {...}
			if topic == Configuration.Internal.Set then
				DataStore:SetData(table.unpack(data))
			elseif topic == Configuration.Internal.Update then
				DataStore:UpdateData(table.unpack(data))
			end
		end)
	end
	
	if IsClient then
		DataStore.LoadedPlayers[Player.UserId] = true
		Send(Configuration.Internal.Spawn)
	end
end)

return DataStore