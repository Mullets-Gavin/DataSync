--[[
	@Author: Gavin "Mullets" Rosenthal
	@Desc: Ping for a player!
--]]

--[[
	DOCUMENTATION:
	https://github.com/Mullets-Gavin/DiceMsgService
	
	API:
	:ConnectKey(key,function)
	:DisconnectKey(key)
	:FireKey(key,message,function)
	:Parse(key,message)
	:Pack(key,tuple)
	.Settings(dictionary)
--]]

--// logic
local MsgService = {}
MsgService.Keys = {}
MsgService.Cache = {}
MsgService.Debug = false
MsgService.Kilobyte = 1024
MsgService.Timeout = 5
MsgService.Default = 'mulletmafiadev'
MsgService.Prefix = '___'
MsgService.Divider = '|'

--// services
local Services = setmetatable({}, {__index = function(cache, serviceName)
	cache[serviceName] = game:GetService(serviceName)
	return cache[serviceName]
end})

--// functions
function MsgService.Settings(dict)
	MsgService.Timeout = dict['Timeout'] or 5
	MsgService.Prefix = dict['Prefix'] or '___'
	MsgService.Debug = dict['Debug'] or false
	MsgService.Divider = dict['Divider'] or '|'
end

function MsgService:Parse(key,message)
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string as first parameter, got '".. typeof(key) .."'")
	assert(typeof(message) == 'string',"[MSG SERVICE]: Expected string as second parameter, got '".. typeof(message) .."'")
	local parse = string.split(message,MsgService.Divider)
	local contents = {}
	for index,data in ipairs(parse) do
		table.insert(contents,data)
	end
	if #contents > 1 then
		return contents
	end
	return message
end

function MsgService:Pack(key,...)
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string as first parameter, got '".. typeof(key) .."'")
	local pack = {...}
	if #pack < 1 then
		if MsgService.Debug then
			warn("[MSG SERVICE]: Function connected to key '".. key .."' returned nothing")
		end
		return nil
	end
	if #pack == 1 then
		local check = pack[1]
		if not tostring(check) then
			if MsgService.Debug then
				warn("[MSG SERVICE]: Contents return by function connected to key '".. key .."' could not be converted")
			end
			return nil
		end
		return check
	else
		local combine = nil
		for index,str in pairs(pack) do
			local convert = tostring(str)
			if not convert then
				if MsgService.Debug then
					warn("[MSG SERVICE]: Not all returned contents from function connected to key '".. key .."' could not be converted")
				end
				return combine
			end
			if combine then
				combine = combine.. MsgService.Divider ..convert
			else
				combine = convert
			end
		end
		return combine
	end
end

function MsgService:FireEvent(key,message,func)
	if Services['RunService']:IsStudio() then return end
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string as first parameter, got '".. typeof(key) .."'")
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string as second parameter, got '".. typeof(key) .."'")
	local replyReceived,replyEvent
	Services['MessagingService']:PublishAsync(key,message)
	if func then
		replyEvent = Services['MessagingService']:SubscribeAsync(MsgService.Prefix..key,function(message)
			local parse = MsgService:Parse(key,message.Data)
			func(parse)
			replyReceived = true
		end)
		local startTime = os.clock()
		while not replyReceived or (os.clock() - startTime) > 5 do
			Services['RunService'].Heartbeat:Wait()
		end
		replyEvent:Disconnect()
	end
end

function MsgService:ConnectKey(key,func)
	if Services['RunService']:IsStudio() then return end
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string as first parameter, got '".. typeof(key) .."'")
	assert(typeof(func) == 'function',"[MSG SERVICE]: Expected function as second parameter, got '".. typeof(func).. "'")
	if MsgService.Cache[key] then
		if MsgService.Debug then
			warn('[MSG SERVICE]: Key is already assigned a function; returning nil')
		end
		return
	end
	MsgService.Cache[key] = {
		['Function'] = func;
		['Event'] = nil;
	}
	MsgService.Cache[key]['Event'] = Services['MessagingService']:SubscribeAsync(key,function(message)
		local results = func(message.Data)
		if not results then return end
		local packedMsg = MsgService:Pack(key,results)
		if tostring(packedMsg) then
			if #packedMsg > MsgService.Kilobyte then
				local previousMsg = packedMsg
				packedMsg = string.sub(packedMsg,1,MsgService.Kilobyte)
				if MsgService.Debug then
					warn("[MSG SERVICE]: Message returning exceeded 1 kilobyte, message '".. previousMsg .."' condensed to '".. packedMsg .."'")
				end
			end
			Services['MessagingService']:PublishAsync(MsgService.Prefix..key,packedMsg)
		end
	end)
end

function MsgService:DisconnectKey(key)
	if Services['RunService']:IsStudio() then return end
	assert(typeof(key) == 'string',"[MSG SERVICE]: Expected string, got '".. typeof(key) .."'")
	if  MsgService.Cache[key] then
		MsgService.Cache[key]['Event']:Disconnect()
		MsgService.Cache[key]['Function'] = nil
		MsgService.Cache[key] = nil
	end
end

return MsgService