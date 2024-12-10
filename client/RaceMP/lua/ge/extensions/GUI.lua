-- Raceboard (Client)

local M = {}

local raceName = "Raceboard"
local logTag = "Raceboard"

M.dependencies = {"ui_imgui"}
local gui_module = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
local im = ui_imgui
local windowOpen = im.BoolPtr(true)
local ffi = require('ffi')

local statisitcs = {} -- name(str) : {name=str, position=number, number=lap (time and splits)}

local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

local function tableLength(t)
    local counter = 0
    for k,v in pairs(t) do
        counter = counter + 1
    end
    return counter
end

local function cleanDecode(input)
    for k,p in pairs(input) do
        for k1,v1 in pairs(p) do
            if tonumber(k1) then
                input[k][tonumber(k1)] = v1
                input[k][k1] = nil
            end
        end
    end
    return input
end

local function configRace(data)
    log('D', logTag, data)
    if data == "null" then
        return
    end

    data = jsonDecode(data)
    raceName = data['raceName'] or raceName
end

--[[
statisitcs = { -- For test data
    [2]={
        ['name'] = "Funky",
        ['position'] = 2,
        [1] = {["lapTime"] = 77.81306498835,
              {['lapSplit'] = 15.250627835563},
              {['lapSplit'] = 43.966324183482},
              {['lapSplit'] = 67.592286749622},
              ['penalty'] = nil},
    },
    [1]={
        ['name'] = "Sarah",
        ['position'] = 1,
        [1] = {["lapTime"] = 66, ["splits"] = nil, ['penalty'] = nil},
        [2] = {["lapTime"] = 86.005629550636, ["splits"] = {
            {['lapSplit'] = 23.996093830061},
            {['lapSplit'] = 52.719295139417},
            {['lapSplit'] = 76.401690133774},
        }, ['penalty'] = 2},
    }
}
]]
local function prettyTime(seconds)
    local thousandths = seconds * 1000
    local mm = math.floor((thousandths / (60 * 1000))) % 60
    local ss = math.floor(thousandths / 1000) % 60
    local ms = math.floor(thousandths % 1000)
    return string.format("%02d:%02d.%d", mm, ss, ms)
end

local function clientRaceboardData(data)

    --log('D', logTag, data)
    if data == "null" then
        return
    end
    data = jsonDecode(data)
    data = cleanDecode(data)

    for id,player in pairs(data) do
        if not player['position'] then
            data[id] = nil -- ignore anyone without a position
        end
    end

    -- Sort by player['position']

    if #data > 1 then
        local function sortPlayers(k1,k2)
            if k1 and k2 then
                return k1['position'] > k2['position']
            elseif k2 then
                return false
            else
                return true
            end
        end
        table.sort(data, sortPlayers)
    end
    --local function sortPlayers(k1,k2) return tonumber(k1['position']) < tonumber(k2['position']) end
    --table.sort(data, sortPlayers)

    for _,player in pairs(data) do
        --[[
        local lastLap   = #player
        if lastLap == 0 or not player[lastLap] then
            goto continue
        end
        if next(player[lastLap]) == nil then
            lastLap = lastLap - 1 -- accounting for initialized laps
        end

        local lastSplit = tableLength(player[lastLap])
        if player[lastLap]['lapTime'] then
            player['lastTime'] = prettyTime(player[lastLap]['lapTime'])
        else
            player['lastTime'] = prettyTime(player[lastLap][lastSplit]['lapSplit'])
        end
        ]]
        local position = tonumber(player['position'])
        --log('D', logTag, "player['position'] : " .. player['position'])
        --log('D', logTag, "type(position) : " .. type(position))
        statisitcs[position] = player
        ::continue::
    end
    for k,p in pairs(statisitcs) do
        log('D', logTag, k .. " : " .. jsonEncode(p))
    end
end

local function drawRaceboard()
    gui.setupWindow(raceName)
    im.Begin(raceName)
    for _,player in pairs(statisitcs) do
        if player['position'] then
            --im.Text(player['position'] .. ": " .. player['name'] .. ": " .. player['lastTime'])
            im.Text(player['position'] .. ": " .. player['name'])
            im.Separator()
        end
    end
end

local function onUpdate(dt)
    if worldReadyState == 2 then
        if windowOpen[0] == true then
            --do return end
            drawRaceboard()
        end
    end
end

local function onWorldReadyState()
    local data = jsonEncode( {} )
    TriggerServerEvent("clientRaceboardReady", data)
end

local function onExtensionLoaded()
    gui_module.initialize(gui)
    gui.registerWindow(raceName, im.ImVec2(512, 256))
    gui.showWindow(raceName)
    log('I', logTag, "Raceboard Loaded")
end

local function onExtensionUnloaded()
    log('I', logTag, "Raceboard Unloaded")
end

AddEventHandler("clientRaceboardData", clientRaceboardData)
AddEventHandler("ConfigRace", configRace)

M.onUpdate = onUpdate
M.onWorldReadyState = onWorldReadyState
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

return M
