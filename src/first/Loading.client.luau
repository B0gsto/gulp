--!strict
-- ReplicatedFirst.Boot.Loading: the custom loading screen (docs/09, section 3).
-- The screen itself arrives with the interface tasks. Until then this only hands over from the
-- default screen once the place has loaded, so nothing shows a half-loaded world.
local ReplicatedFirst = game:GetService("ReplicatedFirst")

if not game:IsLoaded() then
	game.Loaded:Wait()
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
