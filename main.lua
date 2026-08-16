--[[
  Blueprint UI entry point.

  Loads the library and exposes it as a global so any other mod that
  declares a dependency on "blueprint_ui" can just do:
    local UI = B_UI

]]

B_UI = SMODS.load_file("lib/ui.lua")()
