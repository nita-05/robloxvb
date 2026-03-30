-- Hybrid template: Racing placeholder HUD (LocalScript)
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local pg = plr:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("HybridRacingHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "HybridRacingHUD"
gui.ResetOnSpawn = false
gui.Parent = pg

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 200, 0, 28)
label.Position = UDim2.new(0, 12, 0, 12)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(230, 235, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.Text = "Race: GO"
label.Parent = gui

local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 8)
c.Parent = label
