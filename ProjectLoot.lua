-- Project Loot

local P = {}
projectLoot = P
local _G = _G

-- imports
local pairs = pairs
local print = print
local string = string
local table = table
local time = time
local unpack = unpack

local CreateFrame = CreateFrame
local GetMoney = GetMoney
local GetNumLootItems = GetNumLootItems
local GetLootSlotInfo = GetLootSlotInfo
local GetLootSlotLink = GetLootSlotLink
local UnitLevel = UnitLevel
local UnitXP = UnitXP

setfenv(1, P)

loot = {}
events = {}

function track(name, ...)
   table.insert(events, {time(), name, unpack({...})})
end
 
function log(msg, ...)
   print("PL: " .. msg .. ":", ...);
end

function logEvent(self, event, ...)
   log("(" .. event .. ")", ...);
end

function lootSlotOpened(self, event, ...)
   local icon, name, qty, rarity, locked, link, itemId;

   for slot=1, GetNumLootItems() do
      link = GetLootSlotLink(slot);

      if link then
         itemId = string.match(link, "item:(%d+)");
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
   track(eventName, GetMoney(), UnitLevel("player"), UnitXP("player"))
end

function playerLogin(self, event)
   copper = GetMoney();
   playerSnapshot("PLAYER_LOGIN");
end

function flushEvents()
   _G.projectLootEvents = events
end

function playerLogout(self, event)
   playerSnapshot("PLAYER_LOGOUT");
   flushEvents()
end

function playerMoney(self, event)
   local copperNow = GetMoney();

   track("COPPER_CHANGE", copperNow - copper);
   copper = copperNow;
end

function playerLevelUp(self, event, level, ...)
   track("LEVEL_UP", level);
end

function playerDead(self, event)
   track("PLAYER_DEAD");
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
      events = {}
   end
end

function questComplete(self, event)
   print("TODO")
end

function questFinished(self, event)
   print("TODO")
end

function merchantShow(self, event, ...)
   track("MERCHANT_SHOW")
end

-- the MERCHANT_CLOSED event fires twice for whatever reason
merchantClosedCount = 0
function merchantClosed(self, event, ...)
   if 0 < merchantClosedCount then
      merchantClosedCount = 0
   else
      merchantClosedCount = merchantClosedCount + 1
      track("MERCHANT_CLOSED")
   end
end


handlers = {
   -- ["CHAT_MSG_MONEY"] = LogEvent, -- an actual string message
   ["ADDON_LOADED"] = addonLoaded,
   ["ITEM_PUSH"] = logEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = logThenHandle(lootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = logThenHandle(lootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = logEvent,
   ["OPEN_MASTER_LOOT_LIST"] = logEvent,
   ["PLAYER_DEAD"] = playerDead,
   ["PLAYER_LEVEL_UP"] = playerLevelUp,
   ["PLAYER_LOGIN"] = playerLogin,
   ["PLAYER_LOGOUT"] = playerLogout,
   ["PLAYER_MONEY"] = playerMoney,
   ["UPDATE_MASTER_LOOT_LIST"] = logEvent,
   --
   --
   --
   ["MERCHANT_CLOSED"] = logThenHandle(merchantClosed), -- fires twice
   ["MERCHANT_SHOW"] = logThenHandle(merchantShow),
   ["QUEST_COMPLETE"] = logThenHandle(questComplete), -- this is the opening salvo for a quest
   ["QUEST_FINISHED"] = logThenHandle(questFinished),
   ["QUEST_GREETING"] = logEvent, -- fired for givers with > 1 quest
   -- TAXIMAP_OPENED
   -- BANKFRAME_OPENED
   -- TRAINER_SHOW
   -- TRADE_SKILL_SHOW
   -- DELETE_ITEM_CONFIRM
};

frame = CreateFrame("FRAME", "ProjectLootFrame")
for k, v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", eventDispatch);
