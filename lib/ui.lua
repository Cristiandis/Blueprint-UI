--[[
  ui.lua, Blueprint UI core.
  See README.md for usage, syntax, and examples.
]]

local UI = {}

local handler_count = 0
local function register_handler(fn)
  handler_count = handler_count + 1
  local name = "UI_h" .. handler_count
  G.FUNCS[name] = fn
  return name
end

local function is_node(v)
  return type(v) == "table" and v.n ~= nil
end

--#region props

local function build_config(props)
  props = props or {}
  local config = {}

  if props.config then
    for k, v in pairs(props.config) do config[k] = v end
  end

  if props.onClick then config.button = register_handler(props.onClick) end
  if props.func then
    config.func = (type(props.func) == "function") and register_handler(props.func) or props.func
  end
  if props.data then config.data = props.data end

  return config
end

local function make_text(str, props)
  local config = build_config(props)
  config.text = str
  config.scale = config.scale or 0.4
  config.colour = config.colour or G.C.UI.TEXT_LIGHT
  return { n = G.UIT.T, config = config }
end

--#endregion

-- UI.jsx(markup, scope?), compiles <tag> markup into SMODS nodes.
-- See README.md for syntax.

local load_lua = loadstring or load

local function eval_expr(expr, scope)
  local chunk, err = load_lua("return (" .. expr .. ")")
  if not chunk then
    error("UI.jsx: bad expression `" .. expr .. "`: " .. tostring(err), 0)
  end
  setfenv(chunk, setmetatable(scope or {}, { __index = _G }))
  return chunk()
end

local function flatten_into(list, out)
  for _, v in ipairs(list) do
    if is_node(v) then
      out[#out + 1] = v
    elseif type(v) == "table" then
      flatten_into(v, out)
    elseif v ~= nil and v ~= false then
      out[#out + 1] = make_text(tostring(v))
    end
  end
end

local function parse_attr_value(raw, scope)
  if raw:match("^{.*}$") then
    return eval_expr(raw:sub(2, -2), scope)
  end
  if raw == "true" then return true end
  if raw == "false" then return false end
  if raw:match("^%-?%d+%.?%d*$") then return tonumber(raw) end
  return raw
end

local function resolve_fn(raw, scope)
  local v = parse_attr_value(raw, scope)
  return (type(v) == "function") and v or scope[v]
end

local function attrs_to_props(attrs, scope)
  local props = { config = {} }
  for name, raw in pairs(attrs) do
    if name == "onClick" then
      props.onClick = resolve_fn(raw, scope)
    elseif name == "func" then
      props.func = resolve_fn(raw, scope)
    elseif name == "object" then
      props.__object = parse_attr_value(raw, scope)
    elseif name == "data" then
      props.data = parse_attr_value(raw, scope)
    else
      props.config[name] = parse_attr_value(raw, scope)
    end
  end
  return props
end

--#region tokenizer

local function parse_jsx_ast(s)
  local pos, len = 1, #s

  local function skip_ws()
    local _, e = s:find("^%s*", pos)
    pos = e + 1
  end

  local function parse_attrs()
    local attrs = {}
    while true do
      skip_ws()
      local c = s:sub(pos, pos)
      if c == "/" or c == ">" or c == "" then break end
      local name_s, name_e, name = s:find("^([%w_%-]+)", pos)
      if not name then error("UI.jsx: bad attribute near: " .. s:sub(pos, pos + 20), 0) end
      pos = name_e + 1
      skip_ws()
      if s:sub(pos, pos) == "=" then
        pos = pos + 1
        skip_ws()
        local quote = s:sub(pos, pos)
        if quote == '"' or quote == "'" then
          pos = pos + 1
          local close = s:find(quote, pos, true)
          if not close then error("UI.jsx: unterminated value for attribute `" .. name .. "`", 0) end
          attrs[name] = s:sub(pos, close - 1)
          pos = close + 1
        else
          error("UI.jsx: attribute `" .. name .. "` must be quoted", 0)
        end
      else
        attrs[name] = "true"
      end
    end
    return attrs
  end

  local function parse_nodes(stop_tag)
    local nodes = {}
    while pos <= len do
      if s:sub(pos, pos) == "<" then
        if s:sub(pos, pos + 1) == "</" then
          local name_e, name = select(2, s:find("^</%s*([%w_]*)%s*>", pos))
          if not name_e then error("UI.jsx: malformed closing tag near: " .. s:sub(pos, pos + 20), 0) end
          pos = name_e + 1
          if name ~= (stop_tag or "") then
            error(("UI.jsx: mismatched closing tag </%s>, expected </%s>"):format(name, stop_tag or ""), 0)
          end
          return nodes
        else
          local tag_e, tag = select(2, s:find("^<%s*([%w_]*)", pos))
          pos = tag_e + 1
          local attrs = parse_attrs()
          if s:sub(pos, pos + 1) == "/>" then
            pos = pos + 2
            nodes[#nodes + 1] = { type = "tag", tag = tag, attrs = attrs, children = {} }
          elseif s:sub(pos, pos) == ">" then
            pos = pos + 1
            nodes[#nodes + 1] = { type = "tag", tag = tag, attrs = attrs, children = parse_nodes(tag) }
          else
            error("UI.jsx: malformed tag <" .. tag .. ">", 0)
          end
        end
      else
        local next_lt = s:find("<", pos, true) or (len + 1)
        local raw = s:sub(pos, next_lt - 1)
        pos = next_lt
        local i = 1
        while i <= #raw do
          local b_s, b_e = raw:find("{.-}", i)
          if not b_s then
            nodes[#nodes + 1] = { type = "text", value = raw:sub(i) }
            break
          end
          if b_s > i then nodes[#nodes + 1] = { type = "text", value = raw:sub(i, b_s - 1) } end
          nodes[#nodes + 1] = { type = "expr", value = raw:sub(b_s + 1, b_e - 1) }
          i = b_e + 1
        end
      end
    end
    return nodes
  end

  return parse_nodes(nil)
end

--#endregion

--#region AST to SMODS nodes converter

local build_children

local function build_tag(node, scope)
  local tag = node.tag

  if tag == "" or tag == "Fragment" or tag == "frag" then
    return build_children(node.children, scope)
  end

  local props = attrs_to_props(node.attrs, scope)

  if tag == "text" or tag == "span" or tag == "p" then
    local parts = {}
    for _, c in ipairs(node.children) do
      if c.type == "text" then
        parts[#parts + 1] = c.value
      elseif c.type == "expr" then
        parts[#parts + 1] = tostring(eval_expr(c.value, scope))
      else
        error("UI.jsx: <" .. tag .. "> cannot contain nested tags", 0)
      end
    end
    local text = table.concat(parts):gsub("^%s+", ""):gsub("%s+$", "")
    return make_text(text, props)
  end

  local children = build_children(node.children, scope)

  if tag == "root" or tag == "ROOT" then
    return { n = G.UIT.ROOT, config = build_config(props), nodes = children }
  elseif tag == "row" then
    return { n = G.UIT.R, config = build_config(props), nodes = children }
  elseif tag == "col" or tag == "div" then
    return { n = G.UIT.C, config = build_config(props), nodes = children }
  elseif tag == "button" then
    props.config.align = props.config.align or "cm"
    props.config.padding = props.config.padding or 0.1
    props.config.r = props.config.r or 0.1
    props.config.colour = props.config.colour or G.C.BLUE
    props.config.emboss = props.config.emboss or 0.05
    return { n = G.UIT.C, config = build_config(props), nodes = children }
  elseif tag == "box" or tag == "spacer" then
    return { n = G.UIT.B, config = build_config(props) }
  elseif tag == "object" then
    local config = build_config(props)
    config.object = props.__object
    return { n = G.UIT.O, config = config }
  else
    error("UI.jsx: unknown tag <" .. tag .. ">", 0)
  end
end

build_children = function(children, scope, out)
  out = out or {}
  for _, child in ipairs(children) do
    if child.type == "text" then
      local trimmed = child.value:gsub("^%s+", ""):gsub("%s+$", "")
      if trimmed ~= "" then out[#out + 1] = make_text(trimmed) end
    elseif child.type == "expr" then
      local v = eval_expr(child.value, scope)
      if v == nil or v == false then
      elseif is_node(v) then
        out[#out + 1] = v
      elseif type(v) == "table" then
        flatten_into(v, out)
      else
        out[#out + 1] = make_text(tostring(v))
      end
    elseif child.type == "tag" then
      local built = build_tag(child, scope)
      if is_node(built) then
        out[#out + 1] = built
      else
        flatten_into(built, out)
      end
    end
  end
  return out
end

function UI.jsx(markup, scope)
  local ast = parse_jsx_ast(markup)
  local built = build_children(ast, scope or {})
  if #built == 1 then return built[1] end
  return built
end

--#endregion

--#region UIBox helpers

function UI.create(definition, config)
  return UIBox({ definition = definition, config = config or { type = "cm" } })
end

function UI.mount(uibox, props)
  local config = build_config(props)
  config.object = uibox
  return { n = G.UIT.O, config = config }
end

function UI.rerender(mount_node, definition, config)
  local parent = mount_node.config.object.parent
  mount_node.config.object:remove()
  mount_node.config.object = UIBox({
    definition = definition,
    config = config or { parent = parent, type = "cm" },
  })
  parent.UIBox:recalculate()
end

--#endregion

return UI
