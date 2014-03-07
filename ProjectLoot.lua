-- Project Loot

local frame = CreateFrame("FRAME", "ProjectLootFrame");
local loot = {};
events = {};
copper = nil;

local function plLog(msg, ...)
   print("PL: " .. msg .. ":", ...);
end

local function plLogEvent(self, event, ...)
   plLog("(" .. event .. ")", ...);
end

local function plLootSlotOpened(self, event, ...)
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

local function plLootSlotCleared(self, event, slot)
   local time = time();

   plLog("looted", time, loot[slot]);
end

local function plLogThenHandle(handler)
   return function (self, event, ...)
      plLogEvent(self, event, ...);
      handler(self, event, ...);
   end
end

local function plPlayerSnapshot(eventName)
   local copper, level, xp = GetMoney(), UnitLevel("player"), UnitXP("player");

   table.insert(events, {eventName, time(), copper, level, xp})
end

local function plPlayerLogin(self, event)
   copper = GetMoney();
   plPlayerSnapshot("PLAYER_LOGIN");
end

local function plPlayerLogout(self, event)
   plPlayerSnapshot("PLAYER_LOGOUT");
end

local function plPlayerMoney(self, event)
   local copperNow = GetMoney();

   table.insert(events, {"COPPER_CHANGE", time(), copperNow - copper});
   copper = copperNow;
end

local function plPlayerLevelUp(self, event, level, ...)
   table.insert(events, {"LEVEL_UP", time(), level});
end

local function plPlayerDead(self, event)
   table.insert(events, {"PLAYER_DEAD", time()});
end

local handlers = {
   -- ["CHAT_MSG_MONEY"] = plLogEvent, -- an actual string message
   ["ITEM_PUSH"] = plLogEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = plLogThenHandle(plLootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = plLogThenHandle(plLootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = plLogEvent,
   ["OPEN_MASTER_LOOT_LIST"] = plLogEvent,
   ["PLAYER_DEAD"] = plPlayerDead,
   ["PLAYER_LEVEL_UP"] = plPlayerLevelUp,
   ["PLAYER_LOGIN"] = plPlayerLogin,
   ["PLAYER_LOGOUT"] = plPlayerLogout,
   ["PLAYER_MONEY"] = plPlayerMoney,
   ["UPDATE_MASTER_LOOT_LIST"] = plLogEvent,
};

local function plEventDispatch(self, event, ...)
   handlers[event](self, event, ...);
end

for k,v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", plEventDispatch);
