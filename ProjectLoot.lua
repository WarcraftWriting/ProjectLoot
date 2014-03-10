-- Project Loot

local P = {}
projectLoot = P
local _G = _G
SLASH_PROJECT_LOOT1, SLASH_PROJECT_LOOT2 = "/pl", "/projectloot"

-- imports
local pairs = pairs
local print = print
local string = string
local table = table
local time = time
local tonumber = tonumber
local unpack = unpack

local CreateFrame = CreateFrame
local GetContainerItemInfo = GetContainerItemInfo
local GetCVar = GetCVar
local GetLootSlotInfo = GetLootSlotInfo
local GetLootSlotLink = GetLootSlotLink
local GetMoney = GetMoney
local GetNumLootItems = GetNumLootItems
local Logout = Logout
local Quit = Quit
local RequestTimePlayed = RequestTimePlayed
local Screenshot = Screenshot
local SetCVar = SetCVar
local SetView = SetView
local SlashCmdList = SlashCmdList
local UIParent = UIParent
local UnitLevel = UnitLevel
local UnitXP = UnitXP

local timer = projectLootTimer

setfenv(1, P)

loot = {}
events = {}
txCount = 0
inTx = false
snapshot = {}

-- Some events, notably MERCHANT_CLOSED and TRAINER_CLOSED fire twice for some
-- reason.
function handleDoubleClose(handler)
   local closedCount = 0

   return function (self, event, ...)
      if 0 < closedCount then
         closedCount = 0
      else
         closedCount = closedCount + 1
         handler(self, event, ...)
      end
   end
end

function txStatus()
   if inTx then return txCount else return 0 end
end

function txPush()
   txCount = txCount + 1
   inTx = true
end

function txPop()
   inTx = false
end

function trackPush(self, name, ...)
   txPush()
   track(name, ...)
end

function trackPop(self, name, ...)
   track(name, ...)
   txPop()
end

function track(name, ...)
   table.insert(events, {time(), name, txStatus(), unpack({...})})
end

function logThenTrack(self, event, ...)
   log(event, ...)
   track(event, ...)
end

function log(msg, ...)
   if 0 < _G.select("#", ...) then
      print("PL: " .. msg .. ":", ...)
   else
      print("PL:", msg)
   end
end

function logEvent(self, event, ...)
   log("(" .. event .. ")", ...);
end

function itemIdFromLink(link)
   return tonumber(string.match(link, "item:(%d+)"))
end

function logThenHandle(handler)
   return function (self, event, ...)
      logEvent(self, event, ...)
      handler(self, event, ...)
   end
end

function eventDispatch(self, event, ...)
   handlers[event](self, event, ...)
end

function lootSlotOpened(self, event, ...)
   local icon, name, qty, rarity, locked, link, itemId;

   for slot=1, GetNumLootItems() do
      link = GetLootSlotLink(slot);

      if link then
         itemId = itemIdFromLink(link)
         loot[slot] = itemId;
      else
         icon, name, qty, rarity, locked = GetLootSlotInfo(slot);
         loot[slot] = name
      end
   end
end

function lootSlotCleared(self, event, slot)
   track(event, loot[slot])
end

function trackSnapshot(event, callback)
   trackSnapshotCore()
   snapshotFrame:SetScript("OnEvent", snapshotEventHandler(event, function ()
      snapshotFrame:UnregisterAllEvents()
      if callback then callback() end
   end))
   snapshotFrame:RegisterEvent("TIME_PLAYED_MSG")
   RequestTimePlayed()
end

function trackSnapshotCore()
   snapshot.copper = GetMoney()
   snapshot.xp = UnitXP("player")
   snapshot.level = UnitLevel("player")
end

function snapshotEventHandler(event, callback)
   return function (self, _, total)
      snapshot.played = total
      track(event, 
            snapshot.copper, 
            snapshot.level,
            snapshot.xp,
            snapshot.total)
      if callback then callback() end
   end
end

function playerLogin(self, event)
   trackSnapshot(event)
end

function playerLogout(self, event)
   trackSnapshotImmediate(event)
   flushEvents()
end

function flushEvents()
   log("flushing!")
   _G.projectLootEvents = events
end

-- Designed to be called when the player logs out without using the /pl logout
-- or /pl quit command. When this happens, there isn't time to get a played
-- time update, so we replace the value with -1.
function trackSnapshotImmediate(event)
   trackSnapshotCore()
   track(event, snapshot.copper, snapshot.level, snapshot.xp, -1)
end

function playerMoney(self, event)
   local copper = GetMoney()

   logThenTrack(self, event, copper - snapshot.copper)
   -- in the event of a monetary reward from a quest, this event tends to fire
   -- _after_ the QUEST_FINISHED event. Same goes for taxirides, it fires
   -- _after_ TAXIMAP_CLOSED.
   snapshot.copper = copper
end

function takeScreenshot()
   local alpha = UIParent:GetAlpha()
   local format = GetCVar("screenshotFormat")
   local quality = GetCVar("screenshotQuality")
   local frame = CreateFrame("FRAME", "ProjectLootScreenshotFrame")

   log("Say cheese!")
   frame:RegisterEvent("SCREENSHOT_FAILED")
   frame:RegisterEvent("SCREENSHOT_SUCCEEDED")
   frame:SetScript("OnEvent", function (self, event)
      _G.FlipCameraYaw(180)
      SetView(1)                      
      UIParent:Show()
      SetCVar("screenshotFormat", format)
      SetCVar("screenshotQuality", quality)
   end)

   UIParent:Hide()
   -- TODO: these don't seem to have any effect?
   SetCVar("screenshotFormat", "jpg")
   SetCVar("screenshotQuality", 10)
   poseForScreenshot()
end

-- TODO: this could be a LOT cleaner!
function poseForScreenshot()
   local stepTimer = 1.5
   local rotateTimer = 0.5
   local rotateSpeed = 0.02
   local zoomTimer = 1
   local five = function (elapsed)
      _G.MoveViewRightStop()
      Screenshot()
   end
   local four = function (elapsed)
      _G.MoveViewRightStart(rotateSpeed)         
      timer.create(rotateTimer, five)
   end
   local three = function (elapsed)
      _G.CameraZoomOut(5)
      timer.create(zoomTimer, four)
   end
   local two = function (elapsed)
      _G.FlipCameraYaw(180)
      _G.CameraZoomIn(50)
      timer.create(zoomTimer, three)
   end
   local one = function ()
      _G.ResetView(5)
      _G.SetView(5)
      timer.create(stepTimer, two)
   end

   -- TODO disable mouse look
   one()
end

function playerLevelUp(self, event, level, ...)
   snapshot.level = level
   takeScreenshot()
   log("Sign out and get a screenshot from the armory?")
   track(event, level)
end

function playerXpUpdate(self, event, unitId)
   if "player" == unitId then
      local xp = UnitXP(unitId)

      logThenTrack(self, event, xp - snapshot.xp)
      snapshot.xp = xp
   end
end

function itemLocked(self, event, bag, slot)
   local _, qty, locked, _, _, lootable, itemLink = GetContainerItemInfo(bag, slot)

   track(event, bag, slot, itemIdFromLink(itemLink))
end

function itemLockChanged(self, event, bag, slot)
   local _, qty, locked, _, _, lootable, itemLink = GetContainerItemInfo(bag, slot)

   track(event, bag, slot, itemIdFromLink(itemLink), locked)
end

function addonLoaded(self, event, addonName)
   if addonName == "ProjectLoot" then
      -- Our variables, if they exist, have been loaded at this point
      if nil == _G.projectLootEvents then
         events = {}
      else
         events = _G.projectLootEvents
      end
      print("Project Loot Loaded! Go get 'em Tiger!")
   end
end


handlers = {
   -- DELETE_ITEM_CONFIRM
   ["ADDON_LOADED"] = addonLoaded,
   ["BANKFRAME_CLOSED"] = handleDoubleClose(trackPop),
   ["BANKFRAME_OPENED"] = logThenHandle(trackPush),
   ["GOSSIP_CLOSED"] = handleDoubleClose(logThenHandle(trackPop)),
   ["GOSSIP_CONFIRM"] = logThenTrack,
   ["GOSSIP_SHOW"] = logThenHandle(trackPush),
   ["ITEM_LOCK_CHANGED"] = logThenHandle(itemLockChanged),
   ["ITEM_LOCKED"] = logThenHandle(itemLocked),
   ["ITEM_PUSH"] = logEvent, -- doesn't fire on anything too useful?
   ["LEARNED_SPELL_IN_TAB"] = logThenTrack,
   ["LOOT_OPENED"] = logThenHandle(lootSlotOpened),
   ["LOOT_SLOT_CHANGED"] = logEvent, -- is this ever useful? need I rescan?
   ["LOOT_SLOT_CLEARED"] = logThenHandle(lootSlotCleared),
   ["MERCHANT_CLOSED"] = handleDoubleClose(logThenHandle(trackPop)),
   ["MERCHANT_SHOW"] = logThenHandle(trackPush),
   ["OPEN_MASTER_LOOT_LIST"] = logEvent, -- when I get to instances
   ["PLAYER_CONTROL_LOST"] = logThenTrack,
   ["PLAYER_DEAD"] = logThenTrack,
   ["PLAYER_LEVEL_UP"] = logThenHandle(playerLevelUp),
   ["PLAYER_LOGIN"] = playerLogin,
   ["PLAYER_LOGOUT"] = logThenHandle(playerLogout),
   ["PLAYER_MONEY"] = playerMoney,
   ["PLAYER_XP_UPDATE"] = playerXpUpdate,
   ["PLAYERBANKBAGSLOTS_CHANGED"] = logThenTrack,
   ["QUEST_COMPLETE"] = logThenHandle(trackPush),
   ["QUEST_FINISHED"] = logThenHandle(trackPop),
   ["QUEST_GREETING"] = logEvent, -- fired for givers with > 1 quest
   ["TAXIMAP_CLOSED"] = handleDoubleClose(logThenHandle(trackPop)),
   -- TAXIMAP_OPENED is fired even if you know no flight paths connected to
   -- the one you're at. There are two known possible issues for Project Loot
   -- concerning this: We shouldn't count a taxi ride if there isn't a
   -- PLAYER_LOSS_OF_CONTROL fired in the transaction, and also, _if_
   -- TAXIMAP_CLOSED isn't called, then the txCount won't be decremented
   -- correctly.
   ["TAXIMAP_OPENED"] = logThenHandle(trackPush),
   ["TRAINER_CLOSED"] = handleDoubleClose(logThenHandle(trackPop)),
   ["TRAINER_SHOW"] = logThenHandle(trackPush),
   ["UPDATE_MASTER_LOOT_LIST"] = logEvent, -- when I get to instances?
};

frame = CreateFrame("FRAME", "ProjectLootFrame")
for k, v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", eventDispatch);

snapshotFrame = CreateFrame("FRAME", "ProjectLootSnapshotFrame")

SlashCmdList.PROJECT_LOOT = function (msg, editBox)
   if "" == msg then
      print("Available Project Loot commands:")
      print("    clear -- clears all current events")
      print("    logout -- takes a sanpshot of xp, wealth, etc before logging out")
      print("    quit -- takes a snapshot of xp, wealth, etc before quitting")
   elseif "clear" == msg then
      events = {}
      log("Events cleared.")
   elseif "quit" == msg then
      trackSnapshot("QUIT", Quit)
   elseif "logout" == msg then
      trackSnapshot("LOGOUT", Logout)
   elseif "snapshot" == msg then
      trackSnapshot("SLASH", function () print("Snapshotted"); end)
   elseif "ss" == msg or "screenshot" == msg then
      takeScreenshot()
   else
      log("Unrecognized command", msg)
   end
end
