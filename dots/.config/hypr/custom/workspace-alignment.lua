-- Renumber workspace objects, preserving their windows, layout, monitor and focus.
-- Run synchronously in Hyprland so no new window can race the snapshot and moves.
return function()
    local occupied, by_id = {}, {}
    for _, workspace in ipairs(hl.get_workspaces()) do
        if workspace.id > 0 and not workspace.special then
            by_id[workspace.id] = workspace
            if not workspace.is_empty then
                table.insert(occupied, workspace)
            end
        end
    end
    table.sort(occupied, function(a, b) return a.id < b.id end)

    -- An empty workspace can still exist (active on another monitor or persistent).
    -- Swap it into the vacated slot through one unused ID instead of merging it.
    local temporary = #occupied + 1
    while by_id[temporary] do temporary = temporary + 1 end
    local applied = {}
    local function change_id(workspace, id)
        local previous = workspace.id
        local result = hl.dispatch(hl.dsp.workspace.change_id({ workspace = previous, id = id }))
        if not result.ok then
            -- Restore already completed changes in reverse dependency order.
            for i = #applied, 1, -1 do
                local change = applied[i]
                local restored = hl.dispatch(hl.dsp.workspace.change_id({ workspace = change.to, id = change.from }))
                if not restored.ok then
                    error("Workspace alignment rollback failed: " .. tostring(restored.error))
                end
            end
            error("Workspace alignment failed: " .. tostring(result.error))
        end
        by_id[previous], by_id[id] = nil, workspace
        table.insert(applied, { from = previous, to = id })
    end

    for id, workspace in ipairs(occupied) do
        if workspace.id ~= id then
            local previous = workspace.id
            local empty = by_id[id]
            if empty then change_id(empty, temporary) end
            change_id(workspace, id)
            if empty then change_id(empty, previous) end
        end
    end
end
