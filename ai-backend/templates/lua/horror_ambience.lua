-- Hybrid template: Horror ambience (Server)
local Lighting = game:GetService("Lighting")

local function applyOnce()
	if Lighting:GetAttribute("HybridHorrorAmbience") then
		return
	end
	Lighting:SetAttribute("HybridHorrorAmbience", true)

	Lighting.ClockTime = 2
	Lighting.Brightness = 1.5
	Lighting.OutdoorAmbient = Color3.fromRGB(12, 10, 18)
	Lighting.Ambient = Color3.fromRGB(8, 6, 12)

	local atm = Lighting:FindFirstChild("HybridAtmosphere") or Instance.new("Atmosphere")
	atm.Name = "HybridAtmosphere"
	atm.Density = 0.42
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(55, 45, 68)
	atm.Decay = Color3.fromRGB(90, 30, 35)
	atm.Glare = 0.12
	atm.Haze = 0.35
	atm.Parent = Lighting
end

applyOnce()
