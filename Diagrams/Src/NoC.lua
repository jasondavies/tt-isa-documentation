#!/usr/bin/env luajit
-- SPDX-FileCopyrightText: © 2025 Tenstorrent AI ULC
--
-- SPDX-License-Identifier: Apache-2.0

local buffer = require"string.buffer"

local own_dir = debug.getinfo(1, "S").source:match"@?(.*/)" or ""
package.path = own_dir .."?.lua;".. package.path
local Drawing = require"Drawing"

local function TileLabel(x, y)
  if x == 0 then
    local map = {[0] = "D0", "D0", "", "PCIe", "", "D1", "D1", "D1", "", "", "ARC", "D0"}
    return map[y]
  elseif x == 5 then
    local map = {[0] = "D2", "D2", "D3", "D4", "D4", "D5", "D5", "D5", "D4", "D3", "D3", "D2"}
    return map[y]
  elseif y == 0 or y == 6 then
    local map = {1, 3, 5, 7, nil, 6, 4, 2, 0}
    return "E".. (map[x] + (y / 6 * 8))
  else
    local i = (y - (y >= 7 and 2 or 1)) * 8 + (x - (x >= 6 and 2 or 1))
    return "T".. i
  end
end
local tile_colors = {
  P = "#ffd3e2",
  E = "#dae4ff",
  A = "#f2fad3",
  D = "#d6fff8",
  T = "#ffebd3",
  X = "white",
  [""] = "white",
}
local noc_colors = {[0] ="#5c009e", "#06829e"}

local function NoC(noc_id, args)
  local noc_color = noc_colors[noc_id]

  local out = buffer.new()
  local cell_dims = {w = 75, h = 75}
  local noc_size = {w = 10, h = 12}
  local dims = {w = cell_dims.w * noc_size.w + 15, h = cell_dims.h * noc_size.h + 15}
  out:putf([[<svg version="1.1" width="%u" height="%u" xmlns="http://www.w3.org/2000/svg">]], dims.w, dims.h)
  out:putf([[<rect width="%u" height="%u" rx="15" stroke="transparent" fill="white"/>]], dims.w, dims.h)

  local active_hops = {}
  local function key(x, y, port, direction)
    return (("%u_%u_%s_%s"):format(x % noc_size.w, y % noc_size.h, port, direction))
  end
  local function plot_unicast_path(from_x, from_y, to_x, to_y, flip)
    if flip then
      from_x, to_x = to_x, from_x
      from_y, to_y = to_y, from_y
    end
    local x, y = from_x, from_y
    active_hops[key(x, y, "niu", "in")] = true
    while x ~= to_x or y ~= to_y do
      local nx, ny = x, y
      if noc_id == 0 then
        if x ~= to_x then
          nx = (nx + 1) % noc_size.w
        else
          ny = (ny + 1) % noc_size.h
        end
      else
        if y ~= to_y then
          ny = (ny - 1) % noc_size.h
        else
          nx = (nx - 1) % noc_size.w
        end
      end
      if nx ~= x then
        active_hops[key(x, y, "x", "out")] = true
        x, y = nx, ny
        active_hops[key(x, y, "x", "in")] = true
      else
        active_hops[key(x, y, "y", "out")] = true
        x, y = nx, ny
        active_hops[key(x, y, "y", "in")] = true
      end
    end
    active_hops[key(x, y, "niu", "out")] = true
  end
  local function plot_broadcast_path(from_x, from_y, bxy, start_x, start_y, end_x, end_y)
    if noc_id == 1 then
      start_x, end_x = end_x, start_x
      start_y, end_y = end_y, start_y
    end
    local want_x = {}
    local want_x_count = 0
    do
      local x = start_x
      while true do
        want_x[x] = true
        want_x_count = want_x_count + 1
        if x == end_x then break end
        x = (x + (1 - noc_id * 2)) % noc_size.w
      end
    end
    local want_y = {}
    local want_y_count = 0
    do
      local y = start_y
      while true do
        want_y[y] = true
        want_y_count = want_y_count + 1
        if y == end_y then break end
        y = (y + (1 - noc_id * 2)) % noc_size.h
      end
    end

    local x, y = from_x, from_y
    active_hops[key(x, y, "niu", "in")] = true
    if bxy == 0 then
      -- Stage 1: get to start along major axis (X)
      if not want_x[x] then
        while x ~= start_x do
          local nx = (x + (1 - noc_id * 2)) % noc_size.w
          active_hops[key(x, y, "x", "out")] = true
          x = nx
          active_hops[key(x, y, "x", "in")] = true
        end
      end
      -- Stage 3: Cover major axis (X)
      local function fill_major_axis(x, y, want_x_count)
        while true do
          if want_x[x] then
            if TileLabel(x, y):sub(1, 1) == "T" then
              active_hops[key(x, y, "niu", "out")] = true
            end
            want_x_count = want_x_count - 1
            if want_x_count == 0 then break end
          end
          local nx = (x + (1 - noc_id * 2)) % noc_size.w
          active_hops[key(x, y, "x", "out")] = true
          x = nx
          active_hops[key(x, y, "x", "in")] = true
        end
      end
      -- Stage 2: Cover minor axis (Y)
      while true do
        if want_y[y] then
          fill_major_axis(x, y, want_x_count)
          want_y_count = want_y_count - 1
          if want_y_count == 0 then break end
        end
        local ny = (y + (1 - noc_id * 2)) % noc_size.h
        active_hops[key(x, y, "y", "out")] = true
        y = ny
        active_hops[key(x, y, "y", "in")] = true
      end
    else
      -- Stage 1: get to start along major axis (Y)
      if not want_y[y] then
        while y ~= start_y do
          local ny = (y + (1 - noc_id * 2)) % noc_size.h
          active_hops[key(x, y, "y", "out")] = true
          y = ny
          active_hops[key(x, y, "y", "in")] = true
        end
      end
      -- Stage 3: Cover major axis (Y)
      local function fill_major_axis(x, y, want_y_count)
        while true do
          if want_y[y] then
            if TileLabel(x, y):sub(1, 1) == "T" then
              active_hops[key(x, y, "niu", "out")] = true
            end
            want_y_count = want_y_count - 1
            if want_y_count == 0 then break end
          end
          local ny = (y + (1 - noc_id * 2)) % noc_size.h
          active_hops[key(x, y, "y", "out")] = true
          y = ny
          active_hops[key(x, y, "y", "in")] = true
        end
      end
      -- Stage 2: Cover minor axis (X)
      while true do
        if want_x[x] then
          fill_major_axis(x, y, want_y_count)
          want_x_count = want_x_count - 1
          if want_x_count == 0 then break end
        end
        local nx = (x + (1 - noc_id * 2)) % noc_size.w
        active_hops[key(x, y, "x", "out")] = true
        x = nx
        active_hops[key(x, y, "x", "in")] = true
      end
    end
  end

  if args.plot_unicast then
    plot_unicast_path(2, 3, 7, 10)
    if noc_id == 1 then
      plot_unicast_path(7, 8, 4, 2)
    else
      plot_unicast_path(8, 10, 1, 2)
    end
    plot_unicast_path(1, 5, 1, 7, noc_id == 1)
    plot_unicast_path(3, 9, 5, 9, noc_id == 1)
  end
  if args.plot_broadcast then
    plot_broadcast_path(2, 2, args.plot_broadcast, 3, 5, 7, 9)
  end

  local noc_active_color = noc_color
  local noc_inactive_color = noc_color
  if next(active_hops) then
    noc_inactive_color = noc_color .. '" fill-opacity="20%'
  end  

  if noc_id == 0 then
    out:putf('<g transform="translate(%g %g)">\n', 20 + 0.5, 20 + 0.5)
  else
    out:putf('<g transform="translate(%g %g)">\n', cell_dims.w - 7 + 0.5, cell_dims.h - 7 + 0.5)
  end
  for y = noc_id - 1, noc_id + noc_size.h - 1 do
    for x = noc_id - 1, noc_id + noc_size.w - 1 do
      local valid_xy = x >= 0 and y >= 0 and x < noc_size.w and y < noc_size.h
      -- Router
      local cx = x * cell_dims.w
      local cy = y * cell_dims.h
      local r = 9
      local rpad = 13
      if valid_xy then
        local router_active = active_hops[key(x, y, "x", "in")] or active_hops[key(x, y, "x", "out")] or active_hops[key(x, y, "y", "in")] or active_hops[key(x, y, "y", "out")]
        out:putf([[<circle cx="%g" cy="%g" r="%u" stroke="transparent" fill="%s"/>]], cx, cy, r, router_active and noc_active_color or noc_inactive_color)
        out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="middle" fill="white" font-size="80%%">R</text>]], cx, cy + 1)
      end

      -- Tile
      if valid_xy then
        local w = cell_dims.w - rpad * 2
        local h = cell_dims.h - rpad * 2
        local x0 = cx + rpad
        local y0 = cy + rpad
        if noc_id == 1 then
          x0 = cx - rpad - w
          y0 = cy - rpad - h
        end
        local label = TileLabel(x, y)
        local color = tile_colors[label:sub(1, 1)]
        out:putf([[<rect x="%g" y="%g" width="%g" height="%g" stroke="black" fill="%s" stroke-width="1" rx="5" ry="5"/>]], x0, y0, w, h, color)
        if label ~= "" then
          out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="middle">%s</text>]], x0 + w * 0.5, y0 + h * (noc_id == 0 and 0.78 or 0.25), label)
        end
      end

      -- NIU
      if valid_xy then
        local niu_pad = 19
        local x0 = cx + niu_pad
        local y0 = cy + niu_pad
        local w = r * 3 * 1.1
        local h = r * 2 * 1.1
        if noc_id == 1 then
          x0 = cx - niu_pad - w
          y0 = cy - niu_pad - h
        end
        local niu_active = active_hops[key(x, y, "niu", "in")] or active_hops[key(x, y, "niu", "out")]
        out:putf([[<rect x="%g" y="%g" width="%g" height="%g" stroke="transparent" fill="%s" rx="5" ry="5"/>]], x0, y0, w, h, niu_active and noc_active_color or noc_inactive_color)
        out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="middle" fill="white" font-size="80%%">NIU</text>]], x0 + w * 0.5 + 1, y0 + h * 0.5 + 2)
      end

      -- Hops
      if noc_id == 0 then
        -- To other routers:
        Drawing.ThickArrow(out, cx + rpad, cy, "->", cx + cell_dims.w - rpad + 2, cy, active_hops[key(x, y, "x", "out")] and noc_active_color or noc_inactive_color, 1)
        Drawing.ThickArrow(out, cx, cy + rpad, "->", cx, cy + cell_dims.h - rpad + 2, active_hops[key(x, y, "y", "out")] and noc_active_color or noc_inactive_color, 1)
        -- To/from NIU:
        for i = -0.5, 0.5 do
          local x0 = cx + rpad - i * 6.5
          local y0 = cy + rpad + i * 6.5
          local l0 = 5
          local l1 = 8
          Drawing.ThickArrow(out, x0 - l0, y0 - l0, i > 0 and "->" or "<-", x0 + l1, y0 + l1, active_hops[key(x, y, "niu", i > 0 and "out" or "in")] and noc_active_color or noc_inactive_color, 1)
        end
      else
        -- To other routers:
        Drawing.ThickArrow(out, cx - cell_dims.w + rpad - 2, cy, "<-", cx - rpad, cy, active_hops[key(x, y, "x", "out")] and noc_active_color or noc_inactive_color, 1)
        Drawing.ThickArrow(out, cx, cy - cell_dims.h + rpad - 2, "<-", cx, cy - rpad, active_hops[key(x, y, "y", "out")] and noc_active_color or noc_inactive_color, 1)
        -- To/from NIU:
        for i = -0.5, 0.5 do
          local x0 = cx - rpad + i * 6.5
          local y0 = cy - rpad - i * 6.5
          local l0 = 5
          local l1 = 8
          Drawing.ThickArrow(out, x0 - l1, y0 - l1, i > 0 and "->" or "<-", x0 + l0, y0 + l0, active_hops[key(x, y, "niu", i < 0 and "out" or "in")] and noc_active_color or noc_inactive_color, 1)
        end
      end
    end
  end
  out:putf('</g>\n')

  out:putf"</svg>\n"
  return tostring(out)
end

local function NoC_Coords(noc_id, style)
  local noc_size = {w = 10, h = 12}
  local margin = {top = 0, left = 0, right = 0, bottom = 0}

  if style then
    margin.top = 25
    margin.left = 52
    margin.bottom = 5
    margin.right = 5
    if noc_id ~= 0 then
      margin.left, margin.right = margin.right, margin.left
      margin.top, margin.bottom = margin.bottom, margin.top
    end
  end

  local harv_y = {}
  local untrans_x = {}
  local untrans_y = {}
  if style == "translation" then
    harv_y[7] = true
    harv_y[10] = true
    local i = 16
    for _, x in ipairs{0, 5} do
      untrans_x[x] = i
      i = i + 1
    end
    for x = 0, noc_size.w - 1 do
      if not untrans_x[x] then
        untrans_x[x] = i
        i = i + 1
      end
    end
    i = 16
    for _, y in ipairs{0, 6} do
      untrans_y[y] = i
      i = i + 1
    end
    for y = 0, noc_size.h - 1 do
      if not untrans_y[y] and not harv_y[y] then
        untrans_y[y] = i
        i = i + 1
      end
    end
    for y = 0, noc_size.h - 1 do
      if not untrans_y[y] then
        untrans_y[y] = i
        i = i + 1
      end
    end
  end

  local out = buffer.new()
  local cell_dims = {w = 60, h = 60}
  
  
  local dims = {w = cell_dims.w * noc_size.w + 1 + margin.left + margin.right, h = cell_dims.h * noc_size.h + 1 + margin.top + margin.bottom}
  out:putf([[<svg version="1.1" width="%u" height="%u" xmlns="http://www.w3.org/2000/svg">]], dims.w, dims.h)
  out:putf([[<rect width="%u" height="%u" rx="15" stroke="transparent" fill="white"/>]], dims.w, dims.h)

  out:putf('<g transform="translate(%g %g)">\n', margin.left + 0.5, margin.top + 0.5)
  local tpad = 5
  for y = 0, noc_size.h - 1 do
    for x = 0, noc_size.w - 1 do
      local w = cell_dims.w - tpad * 2
      local h = cell_dims.h - tpad * 2
      local x0 = x * cell_dims.w + tpad
      local y0 = y * cell_dims.h + tpad
      local label = TileLabel(x, y)
      if harv_y[y] and label:sub(1, 1) == "T" then
        label = "X"
      end
      local color = tile_colors[label:sub(1, 1)]
      out:putf([[<rect x="%g" y="%g" width="%g" height="%g" stroke="black" fill="%s" stroke-width="1" rx="5" ry="5"/>]], x0, y0, w, h, color)
      x0 = x0 + w * 0.5
      y0 = y0 + h * 0.5
      if label == "X" then
        local sl = w / 4
        local sw = w / 6
        out:putf([[<path d="M %g %g L %g %g" stroke="red" fill="transparent" stroke-width="%g"/>]], x0 - sl, y0 - sl, x0 + sl, y0 + sl, sw)
        out:putf([[<path d="M %g %g L %g %g" stroke="red" fill="transparent" stroke-width="%g"/>]], x0 - sl, y0 + sl, x0 + sl, y0 - sl, sw)
      elseif label ~= "" then
        out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="middle">%s</text>]], x0, y0, label)
      end
    end
  end

  if style then
    local noc_color = noc_colors[noc_id]
    if noc_id == 0 then
      Drawing.ThickArrow(out, tpad, -1, "->", 4 + cell_dims.w * noc_size.w, -1, noc_color, 1)
      Drawing.ThickArrow(out, -1, tpad, "->", -1, 4 + cell_dims.h * noc_size.h, noc_color, 1)
      for x = 0, noc_size.w - 1 do
        local tx = untrans_x[x] or x
        out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="auto" fill="%s">x = %u</text>]], (x + 0.5) * cell_dims.w, -8, noc_color, tx)
      end
      for y = 0, noc_size.h - 1 do
        local ty = untrans_y[y] or y
        out:putf([[<text x="%d" y="%d" text-anchor="end" dominant-baseline="middle" fill="%s">y = %u</text>]], -8, (y + 0.5) * cell_dims.h, noc_color, ty)
      end
    else
      Drawing.ThickArrow(out, -1, cell_dims.h * noc_size.h + 4, "<-", cell_dims.w * noc_size.w - tpad, cell_dims.h * noc_size.h + 4, noc_color, 1)
      Drawing.ThickArrow(out, cell_dims.w * noc_size.w + 4, -1, "<-", cell_dims.w * noc_size.w + 4, cell_dims.h * noc_size.h - tpad, noc_color, 1)
      for x = 0, noc_size.w - 1 do
        local tx = untrans_x[x] or noc_size.w - 1 - x
        out:putf([[<text x="%d" y="%d" text-anchor="middle" dominant-baseline="hanging" fill="%s">x = %u</text>]], (x + 0.5) * cell_dims.w, cell_dims.h * noc_size.h + 8, noc_color, tx)
      end
      for y = 0, noc_size.h - 1 do
        local ty = untrans_y[y] or noc_size.h - 1 - y
        out:putf([[<text x="%d" y="%d" text-anchor="start" dominant-baseline="middle" fill="%s">y = %u</text>]], cell_dims.w * noc_size.w + 8, (y + 0.5) * cell_dims.h, noc_color, ty)
      end
    end
  end

  out:putf('</g>\n')

  out:putf"</svg>\n"
  return tostring(out)
end

local diagrams = {
  Layout = function() return NoC_Coords(0) end,
}
for noc_id = 0, 1 do
  diagrams[noc_id ..""] = function() return NoC(noc_id, {}) end
  diagrams[noc_id .."_Unicast"] = function() return NoC(noc_id, {plot_unicast = true}) end
  for b = 0, 1 do
    diagrams[noc_id .."_Broadcast".. b] = function() return NoC(noc_id, {plot_broadcast = b}) end
  end
  diagrams[noc_id .."_Coords"] = function() return NoC_Coords(noc_id, "noc") end
  diagrams[noc_id .."_TranslationCoords"] = function() return NoC_Coords(noc_id, "translation") end
end
local function do_diagram(which)
  local fn = diagrams[which] or error("Unknown diagram ".. which)
  local output = fn()
  assert(io.open(own_dir .."../Out/NoC_".. which ..".svg", "w")):write(output)
end

local which = ...
if which == nil then
  for k in pairs(diagrams) do
    do_diagram(k)
  end
elseif which then
  do_diagram(which)
end
