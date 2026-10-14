--!strict
-- S11 extra: a directory module (init.luau) that requires its own child with the @self alias.
local Inner = require("@self/Inner")

return { value = Inner.value + 1 }
