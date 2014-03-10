-- Project Loot Timer

-- Project Loot

local P = {}
projectLootTimer = P
local _G = _G

-- imports
local random = random

local CreateFrame = CreateFrame
local UIParent = UIParent

setfenv(1, P)

frame = CreateFrame("FRAME", "ProjectLootTimerFrame")
--timers = {}
--RANDOM_MAX = 2^31-1

function createUpdateHandler(duration, callback)
   local totalElapsed = 0

   return function (self, elapsed)
      totalElapsed = totalElapsed + elapsed

      if totalElapsed > duration then
         destroyHandler()
         callback(totalElapsed)
      end
   end
end

function destroyHandler()
   frame:SetScript("OnUpdate", nil)
end

function create(duration, callback)
   frame:SetScript("OnUpdate", createUpdateHandler(duration, callback))
end


   

