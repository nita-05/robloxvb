-- Hybrid template: Client hint for horror / chase vibe (LocalScript)
local plr = game:GetService("Players").LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")

hum.Died:Connect(function()
	warn("[Hybrid Horror] Character died — respawn or adjust difficulty.")
end)
