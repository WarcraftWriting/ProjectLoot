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
events = _G.projectLootEvents

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
   --table.insert(events, {eventName, time(), copper, level, xp})
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

   table.insert(events, {"COPPER_CHANGE", time(), copperNow - copper});
   copper = copperNow;
end

function playerLevelUp(self, event, level, ...)
   table.insert(events, {"LEVEL_UP", time(), level});
end

function playerDead(self, event)
   table.insert(events, {"PLAYER_DEAD", time()});
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
   end
end


handlers = {
   -- ["CHAT_MSG_MONEY"] = LogEvent, -- an actual string message
   ["ADDON_LOADED"] = addonLoaded,
   ["ITEM_PUSH"] = logEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = logThenHandle(LootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = logThenHandle(LootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = logEvent,
   ["OPEN_MASTER_LOOT_LIST"] = logEvent,
   ["PLAYER_DEAD"] = playerDead,
   ["PLAYER_LEVEL_UP"] = playerLevelUp,
   ["PLAYER_LOGIN"] = playerLogin,
   ["PLAYER_LOGOUT"] = playerLogout,
   ["PLAYER_MONEY"] = playerMoney,
   ["UPDATE_MASTER_LOOT_LIST"] = logEvent,
};

frame = CreateFrame("FRAME", "ProjectLootFrame")
for k, v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", eventDispatch);
