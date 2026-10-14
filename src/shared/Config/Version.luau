--!strict
-- Version: the game version MAJOR.MINOR.PATCH (docs/09, section 17.3). It is shown in settings
-- and sent as an analytics custom field. A release bumps it here (section 17.2, step 2) and tags
-- vMAJOR.MINOR.PATCH. The place version, the save schema version and NET_VERSION live elsewhere.

local MAJOR, MINOR, PATCH = 0, 1, 0

local Version = {
	MAJOR = MAJOR,
	MINOR = MINOR,
	PATCH = PATCH,
	STRING = `{MAJOR}.{MINOR}.{PATCH}`,
}

return Version
