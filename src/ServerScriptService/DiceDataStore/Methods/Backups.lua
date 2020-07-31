--// logic
local Backups = {}
Backups.Enum = {Empty = 'Empty', Fail = 'Fail', Safe = 'Safe'}

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
    cache[serviceName] = game:GetService(serviceName)
    return cache[serviceName]
end})

--// private functions
local function loadPointer(userId,storageKey,dataKey)
	local PointerData,PageData,BackupFile
	
	local callSuccess,callFail = pcall(function()
		PointerData = dataKey:GetSortedAsync(false,1)
		PageData = PointerData:GetCurrentPage()
	end)
	if not callSuccess then
		return Backups.Enum.Fail
	end
	if PageData[1] ~= nil then
		BackupFile = PageData[1].value
	end
	if BackupFile then
		return BackupFile
	end
	return Backups.Enum.Empty
end

function Backups:CreateBackup(userId,storageKey)
	local OrderedDataKey = Services['DataStoreService']:GetOrderedDataStore(storageKey..'_Pointer',userId)
	local GrabPointer = loadPointer(userId,storageKey,OrderedDataKey)
	if GrabPointer == Backups.Enum.Fail then
		warn('[DS]:','Pointer could not safely load: Saving in safe mode')
		return false
	elseif (GrabPointer == Backups.Enum.Empty) or (GrabPointer ~= nil) then
		if GrabPointer == Backups.Enum.Empty then GrabPointer = 0 end
		local newPointer = GrabPointer + 1
		local callSuccess,callFail = pcall(function()
			OrderedDataKey:SetAsync('Save_'..newPointer,newPointer)
		end)
		if not callSuccess then
			warn('[DS]:','Failed to create backup datastore')
			return false
		end
		return newPointer
	end
end

function Backups:LoadBackup(userId,storageKey)
	local OrderedDataKey = Services['DataStoreService']:GetOrderedDataStore(storageKey..'_Pointer',userId)
	local GrabPointer = loadPointer(userId,storageKey,OrderedDataKey)
	if GrabPointer == Backups.Enum.Fail then
		warn('[DS]:','Pointer could not safely load: Loading in safe mode')
		return false
	elseif GrabPointer == Backups.Enum.Empty then
		warn('[DS]:','No backup file loaded: Returning empty')
		return 0
	elseif GrabPointer ~= nil then
		return GrabPointer
	end
end

return Backups