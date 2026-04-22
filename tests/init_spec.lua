---@diagnostic disable: unused-local, unused-function
local MiniTest = require("mini.test")
local helpers = require("fzf-lua.test.helpers")
local child = helpers.new_child_neovim()
local expect = helpers.expect
local eq = expect.equality
local new_set = MiniTest.new_set

local T = helpers.new_set_with_child(child, nil, { winopts = { col = 0, row = 1 } })

T["setup"] = new_set()

---@param picker string
---@return any
local picker_title = function(picker)
  return child.lua(function(name)
    return FzfLua.config.normalize_opts({}, name).winopts.title
  end, { picker })
end

---@param expected table<string, any>
local expect_picker_titles = function(expected)
  for picker, title in pairs(expected) do
    eq(picker_title(picker), title)
  end
end

T["setup"]["setup global vars"] = function()
  -- Global vars
  eq(child.lua_get([[type(_G.FzfLua)]]), "table")
  eq(child.lua_get([[type(vim.g.fzf_lua_server)]]), "string")
  eq(child.lua_get([[type(vim.g.fzf_lua_directory)]]), "string")

  -- Test our custom setup call
  eq(child.lua_get([[type(_G.FzfLua.config.globals.winopts.on_create)]]), "function")
  eq(child.lua_get([[type(_G.FzfLua.config.globals.winopts.on_close)]]), "function")
  eq(child.lua_get([[type(_G.FzfLua.config.globals["winopts.on_create"])]]), "function")
  eq(child.lua_get([[type(_G.FzfLua.config.globals["winopts.on_close"])]]), "function")
  eq(child.lua_get([[_G.FzfLua.config.globals.winopts.col]]), 0)
  eq(child.lua_get([[_G.FzfLua.config.globals.winopts.row]]), 1)

  -- FzfLua command from "plugin/fzf-lua.lua"
  eq(child.fn.exists(":FzfLua") ~= 0, true)

  -- "autoload/fzf_lua.vim"
  eq(child.fn.exists("*fzf_lua#getbufinfo") ~= 0, true)
end

T["setup"]["global winopts.title overrides profile picker titles"] = new_set({
  parametrize = {
    {
      { winopts = { title = false } },
      { files = false, grep = false, ["git.files"] = false },
    },
    {
      { defaults = { winopts = { title = false } } },
      { files = false, grep = false, ["git.files"] = false },
    },
    {
      { winopts = { title = " Global " } },
      { files = " Global ", grep = " Global ", ["git.files"] = " Global " },
    },
    {
      { defaults = { winopts = { title = " Global " } } },
      { files = " Global ", grep = " Global ", ["git.files"] = " Global " },
    },
  },
}, {
  function(setup_opts, expected)
    child.setup(setup_opts)
    expect_picker_titles(expected)
  end,
})

T["setup"]["provider title still overrides global winopts.title"] = function()
  child.setup({
    winopts = { title = false },
    grep = { winopts = { title = " Custom " } },
  })

  expect_picker_titles({
    files = false,
    grep = " Custom ",
  })
end

T["setup"]["global winopts.title survives setup(..., true)"] = function()
  child.setup({ winopts = { title = false } })
  child.lua([[FzfLua.setup({ hls = { normal = "Normal" } }, true)]])

  expect_picker_titles({
    files = false,
    grep = false,
    ["git.files"] = false,
  })
end

T["setup"]["setup highlight groups"] = function()
  -- Highlight groups
  child.cmd("hi! clear")
  expect.match(child.cmd_capture("hi FzfLuaHeaderBind"), "xxx cleared")

  -- Default bg is dark
  child.setup()
  expect.match(child.cmd_capture("hi FzfLuaNormal"), "links to Normal")
  expect.match(child.cmd_capture("hi FzfLuaHeaderBind"), "guifg=BlanchedAlmond")

  child.o.bg = "light"
  child.cmd("hi! clear")
  child.setup()
  expect.match(child.cmd_capture("hi FzfLuaHeaderBind"), "guifg=MediumSpringGreen")
end

return T
