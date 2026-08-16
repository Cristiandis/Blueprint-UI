# Blueprint UI

Real `<tag>` markup compiled directly into Balatro's raw `UIElement`/`UIBox`
node system (Steamodded/SMODS). `UI.jsx` always returns real SMODS node(s)
(`{n=..., config=..., nodes=...}`), so the result drops straight into a
`UIBox` definition, or as a child of any other real node.

Every attribute is a real Balatro config key, written exactly as the game
expects it (`colour`, `align`, `padding`, `r`, `w`, `h`, `scale`, `emboss`,
`outline`, `ref_table`, etc), so anything you already know from the [SMODS UI
Guide](https://docs.smods.dev/Guides/UI-Guide/) works here unchanged.

```lua
local UI = B_UI -- remember to add blueprint_ui as a dependency
```

## Quick example

```lua
local box = UI.create(function()
  return UI.jsx([[
    <root align="cm" padding="0.2">
      <col padding="0.1">
        <text scale="0.5" colour="{G.C.WHITE}">Hello, world!</text>
        <button onClick="onConfirm"><text>Confirm</text></button>
      </col>
    </root>
  ]], { onConfirm = function(e) print("clicked!") end })
end)
```

---

## `UI.jsx(markupString, scope?)`

- Attributes are quoted strings, and are real Balatro config keys
  written exactly as-is. Wrap one in `{...}` to evaluate it as a real Lua
  expression against `scope` (falls back to globals, so `{G.C.RED}`
  works with no scope entry needed).
- `onClick="handlerName"` / `func="handlerName"` look the function up on
  `scope`. `onClick="{expr}"` / `func="{expr}"` evaluate the expression
  directly. Either way it must resolve to a function, and gets
  auto-registered into `G.FUNCS` for you. These are the only two keys
  that need special handling, since the engine requires `button`/`func`
  to be string names rather than real function values.
- Any other attribute is set on the node's config exactly as written.
- `{expr}` as a child can resolve to a node, an array of nodes/strings
  (e.g. from a list-mapping helper), a plain value (stringified), or
  `nil`/`false` to render nothing. That's how conditional rendering
  works: `{cond and "shown"}`.
- `<Fragment>...</Fragment>` or `<>...</>` groups children with no
  wrapper node.
- Known tags: `root`, `row`, `col`/`div`, `text`/`span`/`p`, `button`,
  `box`/`spacer`, `object` (needs an `object="{...}"` attribute).

`<button>` sets a few defaults if you don't override them: `align="cm"`,
`padding=0.1`, `r=0.1`, `colour=G.C.BLUE`, `emboss=0.05`.

### Limitations

- `{expr}` can't contain its own nested braces. An inline table literal
  would break the scan, so put those in `scope` and reference the
  variable name instead.
- `{expr}` can't contain a literal `<` character, for example building
  markup inside markup. The tokenizer scans for tags across the whole
  string and can't tell an in-expression `<` from a real tag boundary.
  Build any nested markup separately and pass the resulting node(s) in
  via `scope`.

---

## UIBox helpers

- `UI.create(definitionFn, config?)` wraps a definition function into a
  real `UIBox` (`config` defaults to `{type = "cm"}`).
- `UI.mount(uibox, props?)` embeds an existing `UIBox` as a node so it can
  be nested inside JSX markup via an `{expr}` child.
- `UI.rerender(mountNode, definitionFn, config?)` rebuilds a mounted
  `UIBox` in place using the delete-and-recreate pattern.

---

## Coverage notes

This covers every node type meant to be hand-built (`ROOT`, `R`, `C`, `T`,
`O`, `B`) and every config key, since any key is accepted as-is.

Not wrapped, by design:

- `G.UIT.S` (slider) / `G.UIT.I` (input). The game itself says not to
  build these raw, so use `create_slider(...)` / `create_text_input(...)`
  and embed the result via `scope` as a normal child.
- Pre-built widget helpers (`UIBox_button`, `create_toggle`,
  `create_option_cycle`, `create_UIBox_generic_options`,
  `simple_text_container`). Call these directly, their output is a real
  node and drops straight into `UI.jsx` markup like anything else.

---

## Files

- `main.lua`: mod entry point, exposes the library as `Blueprint_UI`.
- `lib/ui.lua`: the library itself. Single file, no dependencies beyond
  SMODS/Balatro globals (`G`, `UIBox`, `SMODS`).
- `examples.lua`: a config tab and an extra tab example.
