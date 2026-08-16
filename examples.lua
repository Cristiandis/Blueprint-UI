--[[
  Blueprint UI example usage.

  Two common cases: a mod settings tab, and an extra top-level tab. Both
  just need a function returning UI.jsx(...) with a <root>.
]]

local UI = B_UI

-- ============================================================
-- 1) Config tab (SMODS.current_mod.config_tab)
--
-- Toggles a boolean setting and re-renders the tab in place so the label
-- updates immediately, following the delete+recreate pattern UI.rerender
-- wraps.
-- ============================================================

local config_tab_mount

local function config_tab_definition()
    local config = SMODS.current_mod.config
    return UI.jsx([[
    <root align="cm" padding="0.2">
      <col padding="0.1" r="0.1" colour="{G.C.BLACK}">
        <text scale="0.6" colour="{G.C.WHITE}">Blueprint UI Demo</text>
        <button onClick="toggleEffects">
          <text>{label}</text>
        </button>
      </col>
    </root>
  ]], {
        label = config.bootloader_effects and "Effects: ON" or "Effects: OFF",
        toggleEffects = function(e)
            config.bootloader_effects = not config.bootloader_effects
            UI.rerender(config_tab_mount, config_tab_definition)
        end,
    })
end

SMODS.current_mod.config_tab = function()
    local box = UI.create(config_tab_definition)
    config_tab_mount = UI.mount(box)
    return config_tab_mount
end

-- ============================================================
-- 2) Extra tab (SMODS.current_mod.extra_tabs)
--
-- A simple list built from data, showing {expr} returning an array of
-- nodes (list rendering) and conditional rendering with {cond and ...}.
-- ============================================================

local unlocked_vouchers = { "Bootloader Unlock", "Root Access" }

local function voucher_row(name)
    return UI.jsx([[<text>{name}</text>]], { name = name })
end

SMODS.current_mod.extra_tabs = function()
    return {
        {
            label = "Vouchers",
            tab_definition_function = function()
                local rows = {}
                for _, v in ipairs(unlocked_vouchers) do
                    rows[#rows + 1] = voucher_row(v)
                end

                return UI.jsx([[
          <root align="cm" padding="0.2">
            <col padding="0.1">
              <text scale="0.5" colour="{G.C.WHITE}">Unlocked Vouchers</text>
              <>{rows}</>
              {#rows == 0 and "None yet"}
            </col>
          </root>
        ]], { rows = rows })
            end,
        },
    }
end
