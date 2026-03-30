-- Hybrid template: Lightweight simulator tick (Server)
-- Example pattern: periodic reward; extend in refine step.

local RUNNING = true

task.spawn(function()
	while RUNNING and workspace.Parent do
		task.wait(5)
		-- Hook: grant currency or update stats here
	end
end)
