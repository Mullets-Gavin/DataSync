--// logic
local Methods = {}
Methods.Backups = require(script.Backups)
Methods.Logs = {}
Methods.Events = {}
Methods.CurrentlySaving = {}
Methods.CurrentlyLoading = {}
Methods.RetryCount = 5

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// private functions
function convertTime(givenTime)
	local days = math.floor(givenTime/86400)
	local hours = math.floor(math.modf(givenTime, 86400)/3600)
	local minutes = math.floor(math.modf(givenTime,3600)/60)
	local seconds = math.floor(math.modf(givenTime,60))
	return string.format("%d:%02d:%02d:%02d",days,hours,minutes,seconds)
end

local function SuccessMessage(userId,userName)
	local timeInGame = convertTime(os.time() - Methods.Logs[userId]['Joined'])
	local retryCount = Methods.Logs[userId]['Retries']
	local dataSuccess = Methods.Logs[userId]['Success']
	print('[DS]:',userName..' ('..userId..')','| File size:',Methods.Logs[userId]['Size']..' bytes','| Time in-game:',timeInGame,'| Retries:',retryCount,'| Success:',dataSuccess)
	Methods.Logs[userId] = nil
end

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

function Methods.SaveData(userId,playerFile,storageKey,removeAfter)
	if table.find(Methods.CurrentlySaving,userId) then return end
	if removeAfter ~= 'OVERRIDE' then
		assert(typeof(playerFile) == 'table','[DS]: The file you are trying to save is not a table, can only save dictionaries/tables')
	end
	table.insert(Methods.CurrentlySaving,userId)
	if not Methods.Logs[userId] then Methods.Logs[userId] = {} end
	local DatastoreKey = Services['DataStoreService']:GetDataStore(storageKey..'_Data',userId)
	if removeAfter == 'OVERRIDE' or playerFile['CanSave'] then
		local createBackup = Methods.Backups:CreateBackup(userId,storageKey)
		if tonumber(createBackup) then
			if removeAfter == true then
				playerFile['CanSave'] = false
				playerFile['Loaded'] = false
				Methods.Logs[userId]['Size'] = #Services['HttpService']:JSONEncode(playerFile)
			end
			local callSuccess,callFail
			local retryCount = -1
			repeat
				callSuccess,callFail = pcall(function()
					DatastoreKey:UpdateAsync(createBackup,function()	
						return playerFile
					end)
				end)
				retryCount = retryCount + 1
				if not callSuccess or retryCount < Methods.RetryCount then
					wait(5)
				end
			until callSuccess or retryCount == Methods.RetryCount
			Methods.Logs[userId]['Retries'] = retryCount
			if not callSuccess then
				warn('[DS]:','Failed to save the players data')
				Methods.Logs[userId]['Success'] = false
				pcall(function() table.remove(Methods.CurrentlySaving,table.find(Methods.CurrentlySaving,userId)) end)
				return false,playerFile
			else
				Methods.Logs[userId]['Success'] = true
			end
			if removeAfter == true then
				local Username
				local success,err = pcall(function()
					Username = Services['Players']:GetNameFromUserIdAsync(userId)
				end)
				if not success then
					Username = 'Player'
				end
				SuccessMessage(userId,Username)
			end
			pcall(function() table.remove(Methods.CurrentlySaving,table.find(Methods.CurrentlySaving,userId)) end)
			return true,playerFile
		end
	end
	warn('[DS]:','Player data cannot be saved')
	return false
end

function Methods.LoadData(userId,defaultFile,storageKey)
	if table.find(Methods.CurrentlyLoading,userId) then return end
	assert(typeof(defaultFile) == 'table','[DS]: The default file you are trying to load is not a table, can only load dictionaries/tables')
	table.insert(Methods.CurrentlyLoading,userId)
	if not Methods.Logs[userId] then Methods.Logs[userId] = {['Joined'] = os.time()} end
	local datastoreKey
	local success,err = pcall(function()
		datastoreKey = Services['DataStoreService']:GetDataStore(storageKey..'_Data',userId)
	end)
	local loadBackup = Methods.Backups:LoadBackup(userId,storageKey)
	local playerData,returnedData
	if tonumber(loadBackup) and datastoreKey then -- loaded either successfully or it doesn't exist
		local callSuccess,callFail
		if loadBackup > 1 then
			repeat
				callSuccess,callFail = pcall(function()
					playerData = datastoreKey:GetAsync(loadBackup)
				end)
				if not playerData then
					loadBackup = loadBackup - 1
				end
			until playerData ~= nil or loadBackup == 0
		else
			callSuccess,callFail = pcall(function()
				playerData = datastoreKey:GetAsync(loadBackup)
			end)
		end
		if not callSuccess then
			returnedData = DeepCopy(defaultFile)
			returnedData['Loaded'] = true
			returnedData['CanSave'] = false
			warn('[DS]:','Failed to load the players data')
			pcall(function() table.remove(Methods.CurrentlyLoading,table.find(Methods.CurrentlyLoading,userId)) end)
			return false,returnedData
		end
		
		if playerData == nil then
			returnedData = DeepCopy(defaultFile)
			returnedData['Loaded'] = true
			returnedData['CanSave'] = true
			pcall(function() table.remove(Methods.CurrentlyLoading,table.find(Methods.CurrentlyLoading,userId)) end)
			return true,returnedData
		end
		
		returnedData = playerData
		returnedData['Loaded'] = true
		returnedData['CanSave'] = true
		pcall(function() table.remove(Methods.CurrentlyLoading,table.find(Methods.CurrentlyLoading,userId)) end)
		return true,returnedData
	else
		returnedData = DeepCopy(defaultFile)
		returnedData['Loaded'] = true
		returnedData['CanSave'] = false
		warn('[DS]:','Failed to load the players data')
		pcall(function() table.remove(Methods.CurrentlyLoading,table.find(Methods.CurrentlyLoading,userId)) end)
		return false,returnedData
	end
end

function Methods.GlobalData(key,defaultFile)
	assert(typeof(key) == 'string','[DS]: The globals key you are trying to load with is not a string, can only load keys with strings')
	local datastoreKey
	local success,err = pcall(function()
		datastoreKey = Services['DataStoreService']:GetDataStore(key..'_Data',key)
	end)
	local loadBackup = Methods.Backups:LoadBackup(key,key)
	local globalData,returnedData
	if tonumber(loadBackup) and datastoreKey then
		local callSuccess,callFail = pcall(function()
			globalData = datastoreKey:GetAsync(loadBackup)
		end)
		if not callSuccess then
			returnedData = DeepCopy(defaultFile)
			warn('[DS]:','Failed to load global data')
			return false,returnedData
		end
		
		if globalData == nil then
			returnedData = DeepCopy(defaultFile)
			return true,returnedData
		end
		
		returnedData = globalData
		return true,returnedData
	else
		returnedData = DeepCopy(defaultFile)
		warn('[DS]:','Failed to load global data')
		return false,returnedData
	end
end

return Methods