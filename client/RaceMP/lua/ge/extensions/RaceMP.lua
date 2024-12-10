-- RaceMP (Client) by Dudekahedron and Funky7Monkey 2023

local M = {}

local lapActive = false
local penalty   = 0
local startTime
local splitTime
local stopTime
local lapStart
local lapSplit
local lapTime
local currentSplits = {}
local checkpointTimes = {}
local verifySplits = {}

local prefabActive = false
local prefabPath
local prefabName
local prefabObj

local checkpointCount
local lapCount

local logTag = "RaceMP"

local timer = 0

local function listRaces(_)
    --log('D', logTag, "Listing races")
    local multiplayerFiles = FS:findFiles('/levels/'.. core_levels.getLevelName(getMissionFilename()) ..'/multiplayer/', '*.json', -1, true, false)
    for _, racePath in pairs(multiplayerFiles) do
        guihooks.trigger('toastrMsg', {type="warning", title = "The tracks are:", msg = string.gsub(racePath, "(.*/)(.*)", "%2"):sub(1, -13), config = {timeOut = 10000 }})
    end
end

local function configRace(data)
    log('D', logTag, data)
    if data == "null" then
        return
    end

    data = jsonDecode(data)

    if data["track"] then

        if prefabActive then removePrefab(prefabName) end -- Removes existing prefab

        prefabActive = true
        prefabPath   = "levels/" .. core_levels.getLevelName(getMissionFilename()) .. "/multiplayer/" .. data["track"] .. ".prefab.json"
        prefabName   = string.gsub(prefabPath, "(.*/)(.*)", "%2"):sub(1, -13)
        prefabObj    = spawnPrefab(prefabName, prefabPath, '0 0 0', '0 0 1', '1 1 1')

        checkpointCount = 0
        for _,name in pairs(scenetree.findClassObjects('BeamNGTrigger')) do
            if string.find(name,"lapSplit") then checkpointCount = checkpointCount + 1 end
        end
        log('D', logTag, "checkpointCount:"..checkpointCount)
    end

    lapCount = data["lapCount"] or lapCount

    if prefabActive then
        guihooks.trigger('toastrMsg', {type="error", title = "Track", msg = prefabName .. " layout", config = {timeOut = 2500 }})
    end
    if lapCount then
        guihooks.trigger('toastrMsg', {type="error", title = "Lap Count", msg = lapCount .. " laps", config = {timeOut = 2500 }})
    end
end

local function tableLength(t)
    local counter = 0
    for k,v in pairs(t) do
        counter = counter + 1
    end
    return counter
end

local function prettyTime(seconds)
    local thousandths = seconds * 1000
    local mm = math.floor((thousandths / (60 * 1000))) % 60
    local ss = math.floor(thousandths / 1000) % 60
    local ms = math.floor(thousandths % 1000)
    return string.format("%02d:%02d.%d", mm, ss, ms)
end

local function onLapStart()
    if not lapActive then
        lapActive = true
        penalty = 0
        timer = 0
        startTime = timer
        lapStart = timer
        currentSplits = {}
        checkpointTimes.startStop = lapStart
        checkpointTimes.startTimeStamp = os.time()
        guihooks.trigger('toastrMsg', {type="info", title = "Lap Started!", msg = "Drive through all checkpoints to log a time!", config = {timeOut = 2500 }})
        local data = jsonEncode( { ["startStop"] = checkpointTimes.startStop, ["startTimeStamp"] = checkpointTimes.startTimeStamp } )
        log('D', logTag, data)
        TriggerServerEvent("onLapStart", data)
    end
end

local function onLapSplit(triggerName)
    if lapActive then
        local splitTimeID = tonumber(triggerName:sub(9))
        triggerName = "Checkpoint " .. string.char(splitTimeID+64)
        verifySplits[triggerName] = 1
        splitTime = timer
        lapSplit = splitTime - lapStart
        local prettySplitTime = prettyTime(lapSplit)
        currentSplits[triggerName] = lapSplit
        guihooks.trigger('toastrMsg', {type="info", title = prettySplitTime, msg = triggerName .. " (" .. splitTimeID .. "/" .. checkpointCount .. ")", config = {timeOut = 5000 } })
        local data = jsonEncode( { ["triggerName"] = triggerName, ["lapSplit"] = lapSplit, ['penalty'] = penalty } )
        log('D', logTag, data)
        TriggerServerEvent("onLapSplit", data)
    end
end

local function onLapStop()
    if not lapActive then
        verifySplits = {}
    else
        local missedCheckpoints = checkpointCount - tableLength(verifySplits)
        log('D', logTag, "Missed: " .. missedCheckpoints .. " Count: " .. tableLength(verifySplits))
        if missedCheckpoints ~= 0 then
            guihooks.trigger('toastrMsg', {type="error", title = "Lap Incomplete!", msg = "You must pass through all checkpoints to log an official time!", config = {timeOut = 2500 }})
            penalty = penalty + 1
        end
        stopTime = timer
        lapTime = stopTime - lapStart
        checkpointTimes.startStop = lapTime
        checkpointTimes.stopTimeStamp = os.time()
        verifySplits = {}
        local prettyLapTime = prettyTime(lapTime)
        guihooks.trigger('toastrMsg', {type="info", title = "Great Lap!", msg = "Your Lap Time was: " .. prettyLapTime, config = {timeOut = 5000 }})
        lapActive = false
        local data = jsonEncode( { ["lapTime"] = lapTime, ["currentSplits"] = currentSplits, ['penalty'] = penalty } )
        log('D', logTag, data)
        TriggerServerEvent("onLapStop", data)
        penalty = 0
        timer = 0
    end
end

local function onLapOutOfBounds()
    if lapActive then
        guihooks.trigger('toastrMsg', {type="warning", title = "Out Of Bounds!", msg = "You may continue but the lap time will be marked with a penalty!", config = {timeOut = 5000 }})
        penalty = penalty + 1
    end
end

local function onVehicleResetted(gameVehicleID)
    if MPVehicleGE.isOwn(gameVehicleID) then
        if lapActive then
            guihooks.trigger('toastrMsg', {type="error", title = "Time Forfeit!", msg = "You may continue but checkpoints are not active for this lap!", config = {timeOut = 2500 }})
            lapActive = false
        end
    end
end

local function onPit(data)
    -- To be added
end

local function onBeamNGTrigger(data)
    if data == "null" then
        return
    end
    local trigger = data.triggerName:match("%D*")
    if MPVehicleGE.isOwn(data.subjectID) == true then
        if trigger == "startStop" then
            if data.event == "exit" then
                onLapStart()
            elseif data.event == "enter" then
                onLapStop()
            end
        elseif trigger == "start" and data.event == "enter" then
            onLapStart()
        elseif trigger == "stop" and data.event == "enter" then
            onLapStop()
        elseif trigger == "outOfBounds" and data.event == "enter" then
            onLapOutOfBounds()
        elseif trigger == "lapSplit" and data.event == "enter" then
            onLapSplit(data.triggerName)
        elseif trigger == "pit" and data.event == "enter" then
            onPit(data.triggerName)
        end
    end
end


local function messageReceived(data)
    log('D', logTag, data)
    if data == "null" then
        return
    end
    data = jsonDecode(data)
    if     data['trigger'] == 'toastrMsg' then
        guihooks.trigger('toastrMsg', {type = data["type"], title = data["title"], msg = data["msg"], config = {timeOut = data["timeOut"]}})
    elseif data['trigger'] == 'Message' then
        guihooks.trigger('Message', {ttl = data["ttl"], msg = data["msg"], category = data["category"], icon = data["icon"]})
    elseif data['trigger'] == 'ChangeState' then
        if data['state'] == 'scenario-start' then
            local info = {
                showDataImmediately = true,
                introType = data['type'] or "htmlOnly",
                description = data['description'],
                buttonText = data['buttonText'] or "Okay",
                name = data['title']
            }
            guihooks.trigger('ChangeState', {state = 'scenario-start', params = {data = info}})
        end
    end
end

local function onWorldReadyState()
    local data = jsonEncode( {} )
    log('I', logTag, "RaceMP Ready")
    TriggerServerEvent("clientRaceMPReady", data)
end

local function onExtensionLoaded()
    log('I', logTag, "RaceMP Loaded")
end

local function onExtensionUnloaded()
    log('I', logTag, "RaceMP Unloaded")
end

local function onUpdate(dt)
    timer = timer + dt
    core_environment.setGravity(-9.81)
end

AddEventHandler("RaceMPMessage", messageReceived)

AddEventHandler("ConfigRace", configRace)
AddEventHandler("ListRaces", listRaces)

M.onVehicleResetted = onVehicleResetted

M.onUpdate = onUpdate
M.onWorldReadyState = onWorldReadyState
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onBeamNGTrigger = onBeamNGTrigger

return M
