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
local GetLootSlotInfo = GetLootSlotInfo
local GetLootSlotLink = GetLootSlotLink
local GetMoney = GetMoney
local GetNumLootItems = GetNumLootItems
local SlashCmdList = SlashCmdList
local UnitLevel = UnitLevel
local UnitXP = UnitXP

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

function trackPush(name, ...)
   txPush()
   track(name, ...)
end

function trackPop(name, ...)
   track(name, ...)
   txPop()
end

function track(name, ...)
   table.insert(events, {time(), name, txStatus(), unpack({...})})
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
   local time = time();

   log("looted", time, loot[slot]);
end

function logThenHandle(handler)
   return function (self, event, ...)
      logEvent(self, event, ...);
      handler(self, event, ...);
   end
end

function playerSnapshot(eventName)
   track(eventName, snapshot.copper, snapshot.level, snapshot.xp)
end

function playerLogin(self, event)
   snapshot.copper = GetMoney()
   snapshot.xp = UnitXP("player")
   snapshot.level = UnitLevel("player")

   playerSnapshot("PLAYER_LOGIN")
end

function flushEvents()
   _G.projectLootEvents = events
end

function playerLogout(self, event)
   playerSnapshot("PLAYER_LOGOUT");
   flushEvents()
end

function playerMoney(self, event)
   local copper = GetMoney();

   track("COPPER_CHANGE", copper - snapshot.copper);
   -- in the event of a monetary reward from a quest, this event tends to fire
   -- *after* the QUEST_FINISHED event.
   snapshot.copper = copper;
end

function playerLevelUp(self, event, level, ...)
   snapshot.level = level

   track("LEVEL_UP", level);
end

function playerDead(self, event)
   track("PLAYER_DEAD");
end

function playerXpUpdate(self, event, unitId)
   if "player" == unitId then
      snapshot.xp = UnitXP(unitId)
   else
      log("playerXpUpdate for", unitId)
   end
end

function eventDispatch(self, event, ...)
   handlers[event](self, event, ...);
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

function questComplete(self, event)
   trackPush("QUEST_COMPLETE")
end

function questFinished(self, event)
   trackPop("QUEST_FINISHED")
end

function merchantShow(self, event, ...)
   trackPush("MERCHANT_SHOW")
end

function merchantClosed(self, event, ...)
   trackPop("MERCHANT_CLOSED")
end

function trainerShow(self, event)
   trackPush("TRAINER_SHOW")
end

function trainerClosed(self, event)
   trackPop("TRAINER_CLOSED")
end

function learnedSpellInTab(self, event, spellId, tabNumber)
   track("TRAINED", spellId)
end

function instanceLockStop(self, event)
   track("INSTANCE_LOCK_STOP", "Presumably, you've just quit the game..?")
end

function itemLocked(self, event, bag, slot)
   local _, qty, locked, _, _, lootable, itemLink = GetContainerItemInfo(bag, slot)

   track("ITEM_LOCKED", bag, slot, itemIdFromLink(itemLink))
end

function itemLockChanged(self, event, bag, slot)
   local _, qty, locked, _, _, lootable, itemLink = GetContainerItemInfo(bag, slot)

   track("ITEM_LOCK_CHANGED", bag, slot, itemIdFromLink(itemLink), locked)
end


handlers = {
   -- ["CHAT_MSG_MONEY"] = LogEvent, -- an actual string message
   ["ADDON_LOADED"] = addonLoaded,
   ["ITEM_PUSH"] = logEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = logThenHandle(lootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = logThenHandle(lootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = logEvent,
   ["OPEN_MASTER_LOOT_LIST"] = logEvent,
   ["PLAYER_DEAD"] = logThenHandle(playerDead),
   ["PLAYER_LEVEL_UP"] = logThenHandle(playerLevelUp),
   ["PLAYER_LOGIN"] = playerLogin,
   ["PLAYER_LOGOUT"] = playerLogout,
   ["PLAYER_MONEY"] = logThenHandle(playerMoney),
   ["PLAYER_XP_UPDATE"] = logThenHandle(playerXpUpdate),
   ["UPDATE_MASTER_LOOT_LIST"] = logEvent,
   --
   --
   --
   ["LEARNED_SPELL_IN_TAB"] = logThenHandle(learnedSpellInTab),
   ["MERCHANT_CLOSED"] = handleDoubleClose(logThenHandle(merchantClosed)),
   ["MERCHANT_SHOW"] = logThenHandle(merchantShow),
   ["QUEST_COMPLETE"] = logThenHandle(questComplete), -- this is the opening salvo for a quest
   ["QUEST_FINISHED"] = logThenHandle(questFinished),
   ["QUEST_GREETING"] = logEvent, -- fired for givers with > 1 quest
   -- TAXIMAP_OPENED
   -- BANKFRAME_OPENED
   ["TRAINER_CLOSED"] = handleDoubleClose(logThenHandle(trainerClosed)),
   ["TRAINER_SHOW"] = logThenHandle(trainerShow),
   -- TRADE_SKILL_SHOW
   -- DELETE_ITEM_CONFIRM
   ["INSTANCE_LOCK_STOP"] = logThenHandle(instanceLockStop),

   ["ITEM_LOCKED"] = logThenHandle(itemLocked),
   ["ITEM_LOCK_CHANGED"] = logThenHandle(itemLockChanged),
};

frame = CreateFrame("FRAME", "ProjectLootFrame")
for k, v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", eventDispatch);

SlashCmdList.PROJECT_LOOT = function (msg, editBox)
   if "" == msg then
      print("Available Project Loot commands:")
      print("    clear -- clears all current events")
   elseif "clear" == msg then
      events = {}
      log("Events cleared.")
   else
      log("Unrecognized command", msg)
   end
end

-- item sale:
-- merchant_open
-- item_locked
-- copper_change
-- merchant_closed

-- item purchase:
-- merchant_open
-- item_lock_changed (has item number of purchase)
-- copper_change
-- merchant_closed
