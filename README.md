<div align="center">
<h1>Dice DataStore</h1>

By [Mullet Mafia Dev](https://www.roblox.com/groups/5018486/Mullet-Mafia-Dev#!/about) | [Download](https://www.roblox.com/library/5448889743/Dice-DataStore) | [Source](https://github.com/Mullets-Gavin/DiceDataStore)
</div>

Dice DataStore is a clean and seamless system designed to let you have the most updated information about all of your data on the client and server at every moment. Dice DataStore is meant to be used for player saving & not standalone data design, though there is a way to set a game-based datastore for things such as bans. This system was designed to create a cache file on the server and update the client with their data at an extremely low-cost networking design which will only update the client with new changes to the players datastore, allowing for an easy-access cache file you can use on the client.

## Why Dice DataStore?
Dice DataStore was created for one particular reason: automated replication between client and server. This allows you, the developer, to require the DataStore module in Replicated Storage and have accurate, real time data changes on both the client and server, and even allow you to ping the server for a specific players data. All with super low networking costs.

## Installation
To install Dice DataStore, grab the [Roblox model here](https://www.roblox.com/library/5448889743/Dice-DataStore) and drop it into ServerScriptService. You can also find the release on my [github page here](https://github.com/Mullets-Gavin/DiceDataStore/releases). Download the rbxmxm and drop it into your studio and then drop it into ServerScriptService.

## Games using Dice DataStore
List of all games known to use Dice DataStore:
https://devforum.roblox.com/t/dice-datastore-games/702294

## DiceDataStore Features
- Automatic retries (stops at 5)
- Backups
- Prevents data over writing saves per session
- Saves on BindToClose by default, no need to write your own code
- Super minimal networking with packets
- Real-time data replication
- Globals datastore support, meaning you can have a global datastore for your entire game

## Player Documentation
Change a players data and manipulate the file with a cache that replicates to the client. This is limited down to the player ID provided.

### DiceDataStore:SetData
```lua
:SetData(dataStoreKey,dataStoreDictionary)
```
*Only available on the server.* Set up your default data file that players receive when they join on a key. Provide a dataStoreKey to keep track of your data. dataStoreDictionary should be a dictionary (table) for your data, allowing you to visually see what values are in your default file.

*Example:*
```lua
DiceDataStore:SetData('data_key',{
	['Number'] = 0;
	['Table'] = {};
	['Bool'] = false;
})
```

### DiceDataStore:SetRemoval
```lua
:SetRemoval(dataTable)
```
*Only available on the server.* Set keys that are connected to your Default table to revert back to the original values upon saving the player data. This only happens whenever the player is leaving.

*Example*
```lua
DiceDataStore:SetRemoval({'Number','Bool'}) -- upon leaving, these get set to 0 & false

### DiceDataStore:LoadData
```lua
:LoadData(userID,autoSave)
```
*Only available on the server.* When a player joins a game, you want to load their DataStore file. Call this on a PlayerAdded event with the UserId of the data you are trying to load. autoSave is a boolean value which tells the DataStore to auto save the players cached file every 5 minutes.

**Returns:**
```lua
dataFile --> DataStore File (will return an empty cache file if no data is found)
loadedData --> Boolean if data loaded correctly
```
Check loadedData on join to make sure that DataStores are working properly and if they aren't, this will let you know and you should make player experience better by disabling purchases or preventing the player from joining the game, like Adopt Me.

### DiceDataStore:SaveData
```lua
:SaveData(userID,removeAfter)
```
*Only available on the server.* Saves the current cache on file for the UserId provided, if there is nil data or the game returned false when loading data, the file will not save as it may overwrite pre-existing data.  removeAfter is a boolean value, provide true if you want to remove the player file from the game, like when a player is leaving.

**Returns:**
```lua
dataFile --> DataStore File last saved
loadedData --> Boolean if data loaded correctly
```

### DiceDataStore:GetData
```lua
:GetData(userID,dataFile) --> server
:GetData(dataFile) --> client
:GetData(userID,dataFile) --> optional client
```
If you are calling this on the server, you must require with a UserId present to grab a players data cache file. Provide dataFile as the name of a specific key in your data file if you wish to only grab a certain part of the dataFile. On the client, you do not need the UserId field OR the dataFile if you wish to grab the entire dataFile of the player. If you include dataFile only, you will only get the data of the key in your file. If you provide a UserId, the server is pinged for the most recent file of a player's cache (if in the same server). You can optionally include a dataFile parameter to only ping the server for a specific data.

**Returns:**
```lua
dataFile --> either the entire dictionary OR a specific data value
```

*Example:*
```lua
DiceDataStore:GetData(Plr.UserId,'Number')
```

### DiceDataStore:UpdateData
```lua
:UpdateData(userID,dataFile,newData)
```
*Only available on the server.* Provide a UserId to access the specific players cache and include dataFile as the specific key of the players data you wish to change. To overwrite a players current dictionary completely, simply do not include a newData parameter and only provide a dataFile parameter. This may not save unless you include `['CanSave']` in your new cache file.

**Returns:**
```lua
updatedFile --> the players new updated file specifically for what was called
loadedData --> returns a boolean value if the data was updated successfully
```

*Example:*
```lua
DiceDataStore:UpdateData(Plr.UserId,'Number',100)
```

### DiceDataStore:IncrementData
```lua
:IncrementData(userID,dataFile,newNumber)
```
*Only available on the server.* IncrementData works the same as UpdateData, but allows you to update a specific key by incrementing it.

**Returns:**
```lua
updatedFile --> the players new updated file specifically for what was called
loadedData --> returns a boolean value if the data was updated successfully
```

*Example:*
```lua
DiceDataStore:IncrementData(Plr.UserId,'Number',100) --> add 100
DiceDataStore:IncrementData(Plr.UserId,'Number',-100) --> subtract 100
```

### DiceDataStore:RemoveData
```lua
:RemoveData(userID)
```
*Only available on the server.* Calling this will completely remove and wipe the player datas file. This is great for GDPR requests to quickly remove a players data file from your game. Warning: this will completely wipe every save and you will not be able to recover data. Use this wisely.

### DiceDataStore:WatchData
```lua
:WatchData(userID,dataFile,dataEvent) --> server
:WatchData(dataFile,dataEvent) --> client
```
You can watch specific data keys for changes! Bind a function this call and the function will fire every time that specific data (or the entire file) updates. Do not include dataEvent but rather include the function as the second parameter to fire that function whenever ANY and ALL data updates. Include dataFile as a specific file name to watch that data changing. This will fire whenever any data changes on the client & server.

**Returns:**
```lua
updatedFile --> the players new updated file specifically for what was called
```

*Example:*
```lua
-- fire whenever a specific key is changed
DiceDataStore:WatchData(Plr.UserId,'Number',function(newValue) --> server
	print('Number:',newValue)
end)
DiceDataStore:WatchData('Number',function(newValue) --> client
	print('Number:',newValue)
end)

-- fire whenever any data changes
DiceDataStore:WatchData(Plr.UserId,function(newValue) --> server
	print(newValue)
end)
DiceDataStore:WatchData(function(newValue) --> client
	print(newValue)
end)
```

### DiceDataStore:CalculateSize
```lua
:CalculateSize(userID)
```
*Only available on the server.* Calculate roughly the size of your data file on a UserId and print the data. This uses JSON, which is similar to how DataStores are stored, but this may change and can be unreliable. Treat this as a rough estimate.

## Globals Documentation
Globals is a server datastore that you can call for storing data on your game. This can be useful for things such as ban systems.

### DiceDataStore:SetGlobals
```lua
:SetGlobals(dataStoreKey,dataStoreDictionary)
```
*Only available on the server.* Set your globals DataStore file the same way you call `:SetData` for the player default values.

*Example:*
```lua
DiceDataStore:SetGlobals('server_key',{
	['Bans'] = {};
})
```

### DiceDataStore:GetGlobals
```lua
:GetGlobals(dataFile)
```
Calling GetGlobals will load in the most recent data every time, and does not have a cache. This means you should use this carefully to not throttle the queues (recommended amount is calling it once per player join). dataFile is an optional parameter so you can call a specific key of data.

**Returns:**
```lua
globalsFile --> the globals updated file specifically for what was called
```

*Example:*
```lua
game:GetService('Players').PlayerAdded:Connect(function(Plr)
	local banFile,loadedGlobals = DiceDataStore:GetGlobals('Bans')
	if loadedGlobals and not game:GetService('RunService'):IsStudio() then
		if table.find(banFile,Plr.UserId) then
			Plr:Kick('Banned')
		end
	end
end)
```

### DiceDataStore:UpdateGlobals
```lua
:UpdateGlobals(dataFile,newData)
```
*Only available on the server.* Update a specific key of data by providing dataFile with the key and setting that data to newData, or you can overwrite the entire Globals DataStore by not including newData. Calling this will result in the DataStore automatically saving right away.

**Returns:**
```lua
globalsFile --> the globals updated file specifically for what was called
savedData --> boolean value if the data saved successfully
```

*Example:*
```lua
local banFile,loadedGlobals = DiceDataStore:GetGlobals('Bans')
if loadedGlobals then
	table.insert(banFile,46522586)
	DiceDataStore:UpdateGlobals('Bans',banFile) -- update with the new table changes
	local findPlr = game.Players:GetPlayerByUserId(46522586)
	if findPlr then
		findPlr:Kick('Banned')
	end
end
```

## Example Script
Here's a nifty little script you can use as a template
```lua
-- set up the DataStore module
local DiceDataStore = require(game:GetService('ReplicatedStorage'):WaitForChild('DiceDataStore'))
DiceDataStore:SetData('data_key',{
	['Number'] = 0;
	['Table'] = {};
	['Bool'] = false;
})

local function PlayerAdded(Plr)
	local dataFile,loadedData = DiceDataStore:LoadData(Plr.UserId,true) -- load player data
	if not loadedData then
		-- add protections in case the player data doesn't load
	end
end

game:GetService('Players').PlayerAdded:Connect(function(Plr)
	PlayerAdded(Plr)
end)
for _,Plr in pairs(game:GetService('Players'):GetPlayers()) do
	PlayerAdded(Plr)
end

game:GetService('Players').PlayerRemoving:Connect(function(Plr)
	DiceDataStore:SaveData(Plr.UserId,true) -- save player data when the player leaves
end)
```

---
Made with ♥ by Mullets_Gavin & Mullet Mafia Dev
