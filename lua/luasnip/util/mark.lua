local session = require('luasnip.session')

local Mark = {}

local log_file, err = io.open('/Users/kuro/.local/state/nvim/luasnip_error.log', 'a')
if not log_file then print('[LOGFILE FAILURE] Failed to open log file: ' .. (err or 'unknown error')) end

function Mark:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

-- opts just like in nvim_buf_set_extmark.
local function mark(pos_begin, pos_end, opts)
  return Mark:new({
    id = vim.api.nvim_buf_set_extmark(
      0,
      session.ns_id,
      pos_begin[1],
      pos_begin[2],
      -- override end_* in opts.
      vim.tbl_extend('force', opts, { end_row = pos_end[1], end_col = pos_end[2] })
    ),
    -- store opts here, can't be queried using nvim_buf_get_extmark_by_id.
    opts = opts,
  })
end

local function bytecol_to_utfcol(pos)
  local status, result = pcall(function()
    local lines = vim.api.nvim_buf_get_lines(0, pos[1], pos[1] + 1, false)
    if not lines or #lines == 0 then error('No line content found') end
    local line = lines[1]
    local utf16_indx, _ = vim.str_utfindex(line, pos[2])
    return { pos[1], utf16_indx }
  end)

  if status then return result end

  local error_info = {
    error_message = tostring(result),
    position = string.format('Line: %d, Col: %d', pos[1], pos[2]),
    line_content = vim.inspect(vim.api.nvim_buf_get_lines(0, pos[1], pos[1] + 1, false)),
    buffer_name = vim.api.nvim_buf_get_name(0),
    filetype = vim.bo.filetype,
  }

  -- Create a formatted error message
  local error_msg = string.format(
    'Error in bytecol_to_utfcol:\n'
      .. '  Message: %s\n'
      .. '  Position: %s\n'
      .. '  Line content: %s\n'
      .. '  Buffer: %s\n'
      .. '  Filetype: %s',
    error_info.error_message,
    error_info.position,
    error_info.line_content,
    error_info.buffer_name,
    error_info.filetype
  )

  print('LUASNIP ERROR: ' .. error_msg)

  return pos
end

local function bytecol_to_utfcol_old(pos)
  local line = vim.api.nvim_buf_get_lines(0, pos[1], pos[1] + 1, false)
  -- line[1]: get_lines returns table.
  -- use utf16-index.
  local utf16_indx, _ = vim.str_utfindex(line[1] or '', pos[2])
  return { pos[1], utf16_indx }
end

function Mark:pos_begin_end()
  local mark_info = vim.api.nvim_buf_get_extmark_by_id(0, session.ns_id, self.id, { details = true })

  return bytecol_to_utfcol({ mark_info[1], mark_info[2] }),
    bytecol_to_utfcol({ mark_info[3].end_row, mark_info[3].end_col })
end

function Mark:pos_begin()
  local mark_info = vim.api.nvim_buf_get_extmark_by_id(0, session.ns_id, self.id, { details = false })

  return bytecol_to_utfcol({ mark_info[1], mark_info[2] })
end

function Mark:pos_end()
  local mark_info = vim.api.nvim_buf_get_extmark_by_id(0, session.ns_id, self.id, { details = true })

  return bytecol_to_utfcol({ mark_info[3].end_row, mark_info[3].end_col })
end

function Mark:pos_begin_end_raw()
  local status, mark_info = pcall(vim.api.nvim_buf_get_extmark_by_id, 0, session.ns_id, self.id, { details = true })

  if not status or not mark_info or #mark_info < 3 then
    local info = debug.getinfo(2, 'Slf')
    local info_r = debug.getinfo(3, 'Slf')
    local info_d = debug.getinfo(4, 'Slf')

    local error_msg = string.format(
      'LUASNIP ERROR in Mark:pos_begin_end_raw:\n'
        .. '  Caller Info 1x: %s'
        .. '  Caller Info 2x: %s'
        .. '  Caller Info 3x: %s'
        .. '  Status: %s\n'
        .. '  Error/mark_info: %s\n'
        .. '  self.id: %s\n'
        .. '  session.ns_id: %s\n'
        .. '  Current buffer: %s\n'
        .. '  Current line: %s\n'
        .. '  Filetype: %s',
      vim.inspect(info),
      vim.inspect(info_r),
      vim.inspect(info_d),
      tostring(status),
      vim.inspect(mark_info),
      vim.inspect(self.id),
      vim.inspect(session.ns_id),
      vim.api.nvim_get_current_buf(),
      vim.api.nvim_win_get_cursor(0)[1],
      vim.bo.filetype
    )
    print('ERROR IN Mark:pos_begin_end_raw')

    if log_file then
      log_file:write(error_msg .. '\n')
      log_file:flush()
    end
    return nil, nil
  end

  if mark_info then return { mark_info[1], mark_info[2] }, {
    mark_info[3].end_row,
    mark_info[3].end_col,
  } end
end

function Mark:pos_begin_end_raw_old()
  local mark_info = vim.api.nvim_buf_get_extmark_by_id(0, session.ns_id, self.id, { details = true })
  return { mark_info[1], mark_info[2] }, {
    mark_info[3].end_row,
    mark_info[3].end_col,
  }
end

function Mark:pos_begin_raw()
  local mark_info = vim.api.nvim_buf_get_extmark_by_id(0, session.ns_id, self.id, { details = false })
  return { mark_info[1], mark_info[2] }
end

function Mark:copy_pos_gravs_old(opts)
  local pos_beg, pos_end = self:pos_begin_end_raw()
  opts.right_gravity = self.opts.right_gravity
  opts.end_right_gravity = self.opts.end_right_gravity
  return mark(pos_beg, pos_end, opts)
end

function Mark:copy_pos_gravs(opts)
  local status, result = pcall(function()
    local pos_beg, pos_end = self:pos_begin_end_raw()
    if not pos_beg or not pos_end then error('pos_begin_end_raw returned nil values') end
    opts.right_gravity = self.opts.right_gravity
    opts.end_right_gravity = self.opts.end_right_gravity
    return mark(pos_beg, pos_end, opts)
  end)

  if not status then
    local error_msg = string.format(
      'LUASNIP ERROR in Mark:copy_pos_gravs:\n'
        .. '  Error: %s\n'
        .. '  self.id: %s\n'
        .. '  session.ns_id: %s\n'
        .. '  Current buffer: %s\n'
        .. '  Current line: %s\n'
        .. '  Filetype: %s\n'
        .. '  self.opts: %s\n'
        .. '  Input opts: %s\n'
        .. '  Extmarks in namespace: %s',
      tostring(result),
      vim.inspect(self.id),
      vim.inspect(session.ns_id),
      vim.api.nvim_get_current_buf(),
      vim.api.nvim_win_get_cursor(0)[1],
      vim.bo.filetype,
      vim.inspect(self.opts),
      vim.inspect(opts),
      vim.inspect(vim.api.nvim_buf_get_extmarks(0, session.ns_id, 0, -1, { details = true }))
    )
    --   print(error_msg)
    print('ERROR in Mark:copy_pos_gravs')
    if log_file then
      log_file:write(error_msg .. '\n')
      log_file:flush()
    end

    return nil
  end

  return result
end

-- opts just like in nvim_buf_set_extmark.
-- opts as first arg bcs. pos are pretty likely to stay the same.
function Mark:update_old(opts, pos_begin, pos_end)
  -- if one is changed, the other is likely as well.
  if not pos_begin then
    pos_begin = old_pos_begin
    if not pos_end then pos_end = old_pos_end end
  end
  -- override with new.
  self.opts = vim.tbl_extend('force', self.opts, opts)
  vim.api.nvim_buf_set_extmark(
    0,
    session.ns_id,
    pos_begin[1],
    pos_begin[2],
    vim.tbl_extend('force', self.opts, { id = self.id, end_row = pos_end[1], end_col = pos_end[2] })
  )
end

-- opts just like in nvim_buf_set_extmark.
-- opts as first arg bcs. pos are pretty likely to stay the same.
function Mark:update(opts, pos_begin, pos_end)
  local status, result = pcall(function()
    -- if one is changed, the other is likely as well.
    if not pos_begin or not pos_end then
      local current_begin, current_end = self:pos_begin_end_raw()
      pos_begin, pos_end = pos_begin or current_begin, pos_end or current_end
    end

    self.opts = vim.tbl_extend('force', self.opts, opts)
    return vim.api.nvim_buf_set_extmark(
      0,
      session.ns_id,
      pos_begin[1],
      pos_begin[2],
      vim.tbl_extend('force', self.opts, { id = self.id, end_row = pos_end[1], end_col = pos_end[2] })
    )
  end)

  if not status then
    local error_msg = string.format(
      'LUASNIP ERROR in Mark:update:\n'
        .. '  Error: %s\n'
        .. '  self.id: %s\n'
        .. '  session.ns_id: %s\n'
        .. '  Current buffer: %s\n'
        .. '  Current line: %s\n'
        .. '  Filetype: %s\n'
        .. '  self.opts: %s\n'
        .. '  Input opts: %s\n'
        .. '  pos_begin: %s\n'
        .. '  pos_end: %s\n'
        .. '  Extmarks in namespace: %s',
      tostring(result),
      vim.inspect(self.id),
      vim.inspect(session.ns_id),
      vim.api.nvim_get_current_buf(),
      vim.api.nvim_win_get_cursor(0)[1],
      vim.bo.filetype,
      vim.inspect(self.opts),
      vim.inspect(opts),
      vim.inspect(pos_begin),
      vim.inspect(pos_end),
      vim.inspect(vim.api.nvim_buf_get_extmarks(0, session.ns_id, 0, -1, { details = true }))
    )
    print('ERROR IN Mark:update')
    if log_file then
      log_file:write(error_msg .. '\n')
      log_file:flush()
    end

    return nil
  end

  return result
end

function Mark:set_opts(opts)
  local status, result = pcall(function()
    local pos_begin, pos_end = self:pos_begin_end_raw()

    vim.api.nvim_buf_del_extmark(0, session.ns_id, self.id)

    self.opts = opts

    --- return early here
    if not pos_begin or not pos_end then
      -- print('ERROR:Mark:set_opts returned NIL pos_begin, pos_end')
      -- if init_present then print('Initially pos_begin, pos_end is not nil') end
      return
    end

    -- Frequently, here pos_begin[1] and pos_begin[2] is invalid - causing a crash
    self.id = vim.api.nvim_buf_set_extmark(
      0,
      session.ns_id,
      pos_begin[1],
      pos_begin[2],
      vim.tbl_extend('force', opts, { end_row = pos_end[1], end_col = pos_end[2] })
    )
  end)

  if not status then
    local info = debug.getinfo(2, 'Slf')
    local info_r = debug.getinfo(3, 'Slf')
    local log_msg = string.format(
      'LUASNIP DEBUG Mark:set_opts:\n'
        .. '  Caller Info 1x: %s'
        .. '  Caller Info 2x: %s'
        .. '  Passed Opts: %s'
        .. '  Status: %s\n'
        .. '  Result: %s\n'
        .. '  self.id: %s\n'
        .. '  session.ns_id: %s\n'
        .. '  pos_begin,pos_end raw: %s\n'
        .. '  opts: %s\n'
        .. '  self.opts: %s'
        .. '====================================',
      vim.inspect(info),
      vim.inspect(info_r),
      vim.inspect(opts),
      tostring(status),
      vim.inspect(result),
      tostring(self.id),
      tostring(session.ns_id),
      vim.inspect(self:pos_begin_end_raw()),
      vim.inspect(opts),
      vim.inspect(self.opts)
    )

    print('ERROR IN SET_OPTS')
    if log_file then
      log_file:write(log_msg .. '\n')
      log_file:flush()
    end
  end
end

function Mark:set_opts_old(opts)
  local pos_begin, pos_end = self:pos_begin_end_raw()
  vim.api.nvim_buf_del_extmark(0, session.ns_id, self.id)

  self.opts = opts
  -- set new extmark, current behaviour for updating seems inconsistent,
  -- eg. gravs are reset, deco is kept.

  -- over here frequently pos_begin[1] and pos_begin[2] is invalid - causing a crash
  self.id = vim.api.nvim_buf_set_extmark(
    0,
    session.ns_id,
    pos_begin[1],
    pos_begin[2],
    vim.tbl_extend('force', opts, { end_row = pos_end[1], end_col = pos_end[2] })
  )
end

function Mark:set_rgravs(rgrav_left, rgrav_right)
  -- don't update if nothing would change.
  if self.opts.right_gravity ~= rgrav_left or self.opts.end_right_gravity ~= rgrav_right then
    self.opts.right_gravity = rgrav_left
    self.opts.end_right_gravity = rgrav_right
    self:set_opts(self.opts)
  end
end

function Mark:get_rgrav(which)
  if which == -1 then
    return self.opts.right_gravity
  else
    return self.opts.end_right_gravity
  end
end

function Mark:set_rgrav(which, rgrav)
  if which == -1 then
    if self.opts.right_gravity == rgrav then return end
    self.opts.right_gravity = rgrav
  else
    if self.opts.end_right_gravity == rgrav then return end
    self.opts.end_right_gravity = rgrav
  end
  self:set_opts(self.opts)
end

function Mark:get_endpoint(which)
  -- simpler for now, look into perf here later.
  local l, r = self:pos_begin_end_raw()
  if which == -1 then
    return l
  else
    return r
  end
end

-- change all opts except rgravs.
function Mark:update_opts(opts)
  local opts_cp = vim.deepcopy(opts)
  opts_cp.right_gravity = self.opts.right_gravity
  opts_cp.end_right_gravity = self.opts.end_right_gravity

  -- gets called by Node:set_ext_opts(name) causing the crash
  self:set_opts(opts_cp)
end

function Mark:clear() vim.api.nvim_buf_del_extmark(0, session.ns_id, self.id) end

return {
  mark = mark,
}
