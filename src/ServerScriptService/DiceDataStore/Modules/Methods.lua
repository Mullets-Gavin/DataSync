--// logic
local Methods = {}
Methods.RetryCount = 5
Methods.Cache = {}
Methods.Logs = {}
Methods.Events = {}
Methods.Current = {}
Methods.Internal = {
	['Fire'] = 'Fire';
	['Hook'] = 'Hook';
}

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// variables
local Modules = script.Parent
local MsgService = require(Modules:WaitForChild('MsgService'))
local Manager = require(Modules:WaitForChild('Manager'))

local IsStudio = Services['RunService']:IsStudio()
local IsServer = Services['RunService']:IsServer()
local IsClient = Services['RunService']:IsClient()

--// functions
local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function Methods.SetDefault(key,data)
	if key ~= nil and data ~= nil then
		Methods.Cache[key] = data
	end
end

function Methods:Save(key,index,data)
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	assert(typeof(data) == 'table',"[DICE DATASTORE]: Data 'table' or 'dictionary' expected, got '".. typeof(data) .."'")
	
	if table.find(Methods.Current,index) then return end
	table.insert(Methods.Current,index)
	Manager.spawn(function()
		Manager.wait(6)
		table.remove(Methods.Current,table.find(Methods.Current,index))
	end)
	
	if not Methods.Logs[index] then Methods.Logs[index] = {['Logged'] = os.time()} end
	if data['___PlayingCards'] then
		local datastore = Services['DataStoreService']:GetDataStore(key,index)
		local retry = 0
		local success,err = nil,nil
		repeat
			success,err = pcall(function()
				datastore:UpdateAsync(key..':'..index,function()
					return data
				end)
			end)
			if not success then
				Manager.wait(6)
				retry = retry + 1
			end
		until success or retry == Methods.RetryCount
		Methods.Logs[index]['Retries'] = retry
		Methods.Logs[index]['Key'] = key
		Methods.Logs[index]['Index'] = index
		Methods.Logs[index]['Results'] = success
		Methods.Logs[index]['Size'] = #Services['HttpService']:JSONEncode(data)
		Methods.Logs[index]['Reults'] = success
		Methods.Logs[index] = nil
		Services['RunService'].Heartbeat:Wait()
		return success
	end
	warn('[DICE DATASTORE]: Failed to save',index,'on key',key)
	return false
end

function Methods:Load(key,index)
	assert(typeof(key) == 'string',"[DICE DATASTORE]: Key 'string' expected, got '".. typeof(key) .."'")
	assert(index ~= nil,"[DICE DATASTORE]: Index expected, got '".. typeof(index) .."'")
	
	if table.find(Methods.Current,index) then return end
	table.insert(Methods.Current,index)
	Manager.spawn(function()
		Manager.wait(6)
		table.remove(Methods.Current,table.find(Methods.Current,index))
	end)
	
	if not Methods.Logs[index] then Methods.Logs[index] = {['Logged'] = os.time()} end
	if Methods.Cache[key] then
		local results = {}
		local datastore = Services['DataStoreService']:GetDataStore(key,index)
		local success,err = pcall(function()
			results = datastore:GetAsync(key..':'..index)
		end)
		if not success then
			results = DeepCopy(Methods.Cache[key])
			results['___PlayingCards'] = false
			return results,false
		end
		if results == nil then
			results = DeepCopy(Methods.Cache[key])
			results['___PlayingCards'] = true
			return results,true
		end
		results['___PlayingCards'] = true
		return results,true
	end
end

return Methods