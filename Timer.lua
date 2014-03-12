-- Project Loot Timer

-- The MIT License (MIT)

-- Copyright (c) 2014 Warcraft Writing <warcraftwriting at gmail dot com>

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

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
