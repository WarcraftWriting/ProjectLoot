local P = {}
Stack = P
local _G = _G

local table = table

setfenv(1, P)

function new ()
   return {top = 0}
end

function push(stack, value)
   stack.top = stack.top + 1
   stack[stack.top] = value

   return stack
end

function pop(stack)
   local value = peek(stack)

   stack[stack.top] = nil
   stack.top = stack.top - 1

   return value
end

function peek(stack)
   return stack[stack.top]
end

function isEmpty(stack)
   return 0 == stack.top
end
