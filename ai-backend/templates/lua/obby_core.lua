-- Hybrid template: Obby / parkour core (Server)
-- Expects optional checkpoints as BaseParts under workspace.GeneratedGame.Map named Checkpoint1, Checkpoint2, ...

local Players = game:GetService("Players")

local root = workspace:FindFirstChild("GeneratedGame")
local mapFolder = root and root:FindFirstChild("Map")

local function bindCheckpoint(part)
	if not part:IsA("BasePart") then
		return
	end
	local debounce = false
	part.Touched:Connect(function(hit)
		if debounce then
			return
		end
		local char = hit:FindFirstAncestorOfClass("Model")
		if not char then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local plr = Players:GetPlayerFromCharacter(char)
		if hum and plr and hum.Health > 0 then
			debounce = true
			print("[Hybrid Obby]", plr.Name, "reached", part.Name)
			task.delay(0.35, function()
				debounce = false
			end)
		end
	end)
end

if mapFolder then
	for _, d in ipairs(mapFolder:GetDescendants()) do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 10) == "Checkpoint" then
			bindCheckpoint(d)
		end
	end
else
	warn("[Hybrid Obby] GeneratedGame.Map missing — add checkpoints later.")
end
