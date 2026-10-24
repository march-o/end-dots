-- Execute the production callback with compositor-like workspace objects.
-- No desktop connection or real windows are used.
local align = assert(loadfile(arg[1] or "dots/.config/hypr/custom/workspace-alignment.lua"))()
local tested = 0

local function exercise(spec, fail_at)
    local workspaces, occupied, original = {}, {}, {}
    for _, entry in ipairs(spec) do
        local workspace = {
            id = entry[1], is_empty = entry[2] == 0, special = entry[1] < 0,
            name = entry[3] or tostring(entry[1]),
            -- These must retain identity even across active/multi-monitor moves.
            windows = {}, layout = {}, monitor = {}, fullscreen_window = {},
            active = true, visible = true,
        }
        table.insert(workspaces, workspace)
        original[workspace] = workspace.id
        if workspace.id > 0 and not workspace.is_empty then
            table.insert(occupied, workspace)
        end
    end
    table.sort(occupied, function(a, b) return a.id < b.id end)
    local focused = workspaces[#workspaces]
    local snapshots = {}
    for _, w in ipairs(workspaces) do
        snapshots[w] = { w.windows, w.layout, w.monitor, w.fullscreen_window, w.name }
    end
    local calls = 0
    hl = {
        get_workspaces = function() return workspaces end,
        dsp = { workspace = { change_id = function(args) return args end } },
        dispatch = function(args)
            calls = calls + 1
            if calls == fail_at then return { ok = false, error = "injected failure" } end
            local target
            for _, w in ipairs(workspaces) do
                assert(w.id ~= args.id, "destination collision")
                if w.id == args.workspace then target = w end
            end
            assert(target and target.id > 0, "missing or managed source")
            target.id = args.id
            return { ok = true }
        end,
    }
    local ok, err = pcall(align)
    if fail_at and fail_at <= calls then
        assert(not ok and err:find("injected failure", 1, true), tostring(err))
        for _, w in ipairs(workspaces) do assert(w.id == original[w], "incomplete rollback") end
    else
        assert(ok, err)
        for id, w in ipairs(occupied) do assert(w.id == id, "gap or reordered workspace") end
        local previous_calls = calls
        align()
        assert(calls == previous_calls, "alignment must be idempotent")
    end
    for _, w in ipairs(workspaces) do
        local s = snapshots[w]
        assert(w.windows == s[1] and w.layout == s[2] and w.monitor == s[3])
        assert(w.fullscreen_window == s[4] and w.name == s[5] and w.active and w.visible)
        if w.id < 0 then assert(w.id == original[w], "special/named workspace moved") end
    end
    assert(focused == workspaces[#workspaces], "focus changed")
    tested = tested + 1
    return calls
end

exercise({ { 1, 1 }, { 2, 0 }, { 3, 1 } }) -- User's example; retained empty workspace.
exercise({ { 1, 1 }, { 3, 1 }, { 7, 1 } }) -- Uncreated gaps.
exercise({ { 9, 1 }, { 3, 1 }, { 5, 1 }, { 1, 0 }, { 2, 0 } }) -- Unsorted/chained swaps.
exercise({ { -98, 1, "special:spotify" }, { -1337, 1, "named" }, { 5, 1 } })
exercise({ { 2147483647, 1 }, { 1, 0 }, { 2, 0 } }) -- Temporary ID does not overflow.
exercise({ { 6, 1, "Development" }, { 1, 0 } }) -- Renamed numeric workspace.
exercise({})
exercise({ { 1, 0 }, { 2, 0 } })

-- Every absent/empty/occupied combination through workspace 8, in reverse order.
for code = 0, 3 ^ 8 - 1 do
    local spec, remaining = {}, code
    for id = 8, 1, -1 do
        local state = remaining % 3
        remaining = math.floor(remaining / 3)
        if state > 0 then table.insert(spec, { id, state - 1 }) end
    end
    exercise(spec)
end

-- Fail each native dispatch in a sequence with chained empty-workspace swaps.
local rollback_spec = { { 1, 0 }, { 2, 0 }, { 3, 1 }, { 5, 1 }, { 9, 1 } }
local total = exercise(rollback_spec)
for fail_at = 1, total do exercise(rollback_spec, fail_at) end
print("Workspace alignment: " .. tested .. " scenarios passed")
