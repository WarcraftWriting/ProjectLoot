-- Project Loot

local frame = CreateFrame("FRAME", "ProjectLootFrame");
local playerName = UnitName("player");
local realm = GetRealmName();
local loot = {};

local function plLogEvent(self, event, ...)
   local k, v;

   print("Project Loot: (" .. event .. ")");
   -- can I use for i,v in ipairs(...) do?
   for k=1, select("#", ...) do
      v = select(k, ...)
      if v then
         print("  [" .. v .. "]");
      end
   end
end

local function plLootSlotOpened(self, event, ...)
   for i=1,GetNumLootItems() do
      local icon, name, qty, rarity, locked = GetLootSlotInfo(i);
      local link = GetLootSlotLink(i);
      local now = time();

      if link then
         local itemId = string.match(link, "item:(%d+)");
         print("itemId: " .. itemId);

         loot[i] = {now, realm, playerName, itemId};
         --print("Loot: " .. qty .. " x " .. name);
      else
         print("no link for slot: " .. i);
      end
   end
end

local function plLootSlotCleared(self, event, ...)
   local time = time();
   local slot = select(1, ...);
   print("looting slot: ", slot);
   --print("raw: " .. loot[slot][4]);

   -- local icon, name, qty, rarity, locked = GetLootSlotInfo(slot);
   -- local link = GetLootSlotLink(slot);
   -- if link then
   --    local itemId = string.match(link, "item:(%d+)");
   --    print("itemId [cleared]: " .. itemId);
   -- else
   --    print("no link found for: " .. slot);
   -- end

   -- TODO: try this:
   -- t, r, pn, id = unpack(loot[slot]);
   -- http://www.lua.org/manual/5.1/manual.html#pdf-unpack
   local t = loot[slot][1];
   local r = loot[slot][2];
   local pn = loot[slot][3];
   local itemId = loot[slot][4];

   print("raw", t, r, pn, itemId);
   if itemId then
      print("looted: " .. t .. "," .. r .. "," .. pn .. "," .. itemId);
   else
      print("looted: " .. t .. "," .. r .. "," .. pn .. "," .. "<unknown>");
   end
end

local function plLogThenHandle(handler)
   return function (self, event, ...)
      plLogEvent(self, event, ...);
      handler(self, event, ...);
   end
end

local handlers = {
   -- ["CHAT_MSG_MONEY"] = plLogEvent, -- an actual string message
   ["ITEM_PUSH"] = plLogEvent, -- doesn't fire on anything too useful?
   ["LOOT_OPENED"] = plLogThenHandle(plLootSlotOpened),
   ["LOOT_SLOT_CLEARED"] = plLogThenHandle(plLootSlotCleared),
   ["LOOT_SLOT_CHANGED"] = plLogEvent,
   ["OPEN_MASTER_LOOT_LIST"] = plLogEvent,
   ["PLAYER_ENTERING_WORLD"] = plLogEvent,
   ["UPDATE_MASTER_LOOT_LIST"] = plLogEvent,
};

local function plEventDispatch(self, event, ...)
   handlers[event](self, event, ...);
end

for k,v in pairs(handlers) do
   frame:RegisterEvent(k);
end
frame:SetScript("OnEvent", plEventDispatch);
