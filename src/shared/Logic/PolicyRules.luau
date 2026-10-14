--!strict
-- PolicyRules: the pure half of the PolicyService check at join (docs/09, section 18.2).
-- PlayerLifecycle calls `PolicyService:GetPolicyInfoForPlayerAsync` inside pcall and passes the
-- outcome here. If the call failed, every field takes its most restrictive value; so does any
-- field the answer lacks or gives with the wrong type. Tables only, so it runs in Lune.
export type Policy = {
	ArePaidRandomItemsRestricted: boolean,
	IsPaidItemTradingAllowed: boolean,
	AreAdsAllowed: boolean,
	IsEligibleToPurchaseSubscription: boolean,
	IsSubjectToChinaPolicies: boolean,
	IsContentSharingAllowed: boolean,
	AllowedExternalLinkReferences: { string },
}

local PolicyRules = {}

--- The most restrictive value of every field: what a failed call is read as.
PolicyRules.MOST_RESTRICTIVE = table.freeze({
	ArePaidRandomItemsRestricted = true,
	IsPaidItemTradingAllowed = false,
	AreAdsAllowed = false,
	IsEligibleToPurchaseSubscription = false,
	IsSubjectToChinaPolicies = true,
	IsContentSharingAllowed = false,
	AllowedExternalLinkReferences = table.freeze({}) :: { string },
} :: Policy)

local BOOLEAN_FIELDS = {
	"ArePaidRandomItemsRestricted",
	"IsPaidItemTradingAllowed",
	"AreAdsAllowed",
	"IsEligibleToPurchaseSubscription",
	"IsSubjectToChinaPolicies",
	"IsContentSharingAllowed",
}

--- The policy to store for a player, from pcall's two results. A failed call, or an answer that
--- is not a table, gives `MOST_RESTRICTIVE`; otherwise each field missing or of the wrong type
--- falls back to its most restrictive value.
function PolicyRules.from(ok: boolean, result: unknown): Policy
	if not ok or type(result) ~= "table" then
		return PolicyRules.MOST_RESTRICTIVE
	end
	local raw = result :: { [string]: unknown } -- safe: checked to be a table just above
	local out: { [string]: unknown } = {}
	local restrictive = (PolicyRules.MOST_RESTRICTIVE :: any) :: { [string]: unknown }
	for _, field in BOOLEAN_FIELDS do
		local value = raw[field]
		out[field] = if type(value) == "boolean" then value else restrictive[field]
	end
	local links: { string } = {}
	local rawLinks = raw.AllowedExternalLinkReferences
	if type(rawLinks) == "table" then
		for _, link in rawLinks :: { unknown } do
			if type(link) == "string" then
				table.insert(links, link)
			end
		end
	end
	out.AllowedExternalLinkReferences = table.freeze(links)
	-- Safe cast: every field of Policy was written above with its type.
	return table.freeze(out) :: any
end

return table.freeze(PolicyRules)
