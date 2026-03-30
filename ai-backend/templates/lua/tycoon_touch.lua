-- Hybrid template: Simple tycoon button touch credit (Server)
local Players = game:GetService("Players")

local root = workspace:FindFirstChild("GeneratedGame")
local assetFolder = root and root:FindFirstChild("Assets")

if not assetFolder then
	warn("[Hybrid Tycoon] GeneratedGame.Assets missing.")
	return
end

local deb = {}
local function onTouched(plate, hit)
	local id = plate:GetFullName()
	if deb[id] then
		return
	end
	local char = hit and hit:FindFirstAncestorOfClass("Model")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local plr = hum and Players:GetPlayerFromCharacter(char)
	if not plr or hum.Health <= 0 then
		return
	end
	deb[id] = true
	print("[Hybrid Tycoon]", plr.Name, "activated", plate.Name)
	task.delay(1.5, function()
		deb[id] = nil
	end)
end

for _, d in ipairs(assetFolder:GetDescendants()) do
	if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "Tycoon" then
		d.Touched:Connect(function(hit)
			onTouched(d, hit)
		end)
	end
end

