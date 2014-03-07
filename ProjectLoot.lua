-- Project Loot

local frame = CreateFrame("FRAME", "ProjectLootFrame");
local playerName = UnitName("player");
local realm = GetRealmName();
local loot = {};

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
   local time, playerName = time(), UnitName("player");

   plLog("looted", time, realm, playerName, loot[slot]);
end

local function plLogThenHandle(handler)
   return function (self, event, ...)
      plLogEvent(self, event, ...);
      handler(self, event, ...);
   end
end

local function plPlayerEnteringWorld(self, event)
   local copper, level, xp = GetMoney(), UnitLevel("player"), UnitXP("player");

   plLog("foo", 1, 2, 3);
   plLog("session start", time(), realm, UnitName("player"), copper, level, xp);
end

local handlers = {
   -- ["CHAT_MSG_MONEY"] = plLogEvent, -- an actual string message
   ["ITEM_PUSH"] = plLogEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = plLogThenHandle(plLootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = plLogThenHandle(plLootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = plLogEvent,
   ["OPEN_MASTER_LOOT_LIST"] = plLogEvent,
   ["PLAYER_ENTERING_WORLD"] = plPlayerEnteringWorld,
   ["UPDATE_MASTER_LOOT_LIST"] = plLogEvent,
};

local function plEventDispatch(self, event, ...)
   handlers[event](self, event, ...);
end

for k,v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", plEventDispatch);
