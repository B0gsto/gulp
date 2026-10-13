--!strict
-- Content generator: docs tables → src/shared/Data/Generated (docs/09, section 3.2).
--   lune run tools/gen/content
-- Skeleton only. Task S1-C5 (module B04) writes the real generator; until then this writes no
-- file, so the `gen` step of tools/check.luau and the `gen` CI job have nothing to compare.
local Files = require("../lib/files")

local OUTPUT_ROOT = "src/shared/Data/Generated"

Files.requireRepoRoot()
print(`gen: no tables are generated yet (task S1-C5); wrote 0 modules to {OUTPUT_ROOT}`)
