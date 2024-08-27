local Config = require("persistence.config")

local uv = vim.uv or vim.loop

local M = {}

local e = vim.fn.fnameescape

---@param opts? {branch?: boolean, name?: string}
function M.current(opts)
  opts = opts or {}

  local name
  if opts.name then
    name = opts.name:gsub("[\\/:]+", "%%")
  else
    name = vim.fn.getcwd():gsub("[\\/:]+", "%%")
  end

  if Config.options.branch or opts.branch ~= false then
    local branch = M.branch()
    if branch and branch ~= "main" and branch ~= "master" then
      name = name .. "%%" .. branch:gsub("[\\/:]+", "%%")
    end
  end
  return Config.options.dir .. name .. ".vim"
end

function M.setup(opts)
  Config.setup(opts)
end

function M.fire(event)
  vim.api.nvim_exec_autocmds("User", {
    pattern = "Persistence" .. event,
  })
end

---@param opts? {branch?: boolean, name?: string}
function M.save(opts)
  opts = opts or {}
  M.fire("SavePre")
  vim.cmd("mks! " .. e(M.current(opts)))
  M.fire("SavePost")
end

---@param opts? { branch?: boolean, last?: boolean, name?: string }
function M.load(opts)
  opts = opts or {}
  ---@type string
  local file
  if opts.last then
    file = M.last()
  else
    file = M.current(opts)
    if vim.fn.filereadable(file) == 0 then
      file = M.current({ branch = false, name = opts.name })
    end
  end
  if file and vim.fn.filereadable(file) ~= 0 then
    M.fire("LoadPre")
    vim.cmd("silent! source " .. e(file))
    M.fire("LoadPost")
  end
end

---@return string[]
function M.list()
  local sessions = vim.fn.glob(Config.options.dir .. "*.vim", true, true)
  table.sort(sessions, function(a, b)
    return uv.fs_stat(a).mtime.sec > uv.fs_stat(b).mtime.sec
  end)
  return sessions
end

function M.last()
  return M.list()[1]
end

--- get current branch name
---@return string?
function M.branch()
  if uv.fs_stat(".git") then
    local ret = vim.fn.systemlist("git branch --show-current")[1]
    return vim.v.shell_error == 0 and ret or nil
  end
end

return M
