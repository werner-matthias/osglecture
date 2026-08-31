--[[
  Package: semcat
  Date:
  2026-08-31
  Version:
  v0.2.0
]]
--<*lua>
local M = {}

-- Percent-encodes everything outside the URL-safe unreserved set
-- (RFC 3986), so a QR redirect target survives arbitrary document ids
-- and jobnames without the caller having to sanitize them by hand.
function M.urlencode(str)
  str = str:gsub(
    "([^%w%-%_%.%~])",
    function(c) return string.format("%%%02X", string.byte(c)) end
  )
  return str
end

-- Draws a continuous, page-break-safe margin bar for a block-level
-- marking. Unlike changebar's output-routine hook, this decorates
-- every output line at paragraph-breaking time (post_linebreak_filter),
-- well before the page-breaking decision is even made, so a bar
-- spanning a page break needs no special handling: each line already
-- carries its own copy of the mark by the time the page is assembled.
M.bar_active_box = nil
M.bar_gap = tex.sp("2pt")

local function clone_rule_for_line(line)
  local list = node.copy_list(tex.box[M.bar_active_box].list)
  local width = 0
  local n = list
  while n do
    if n.id == node.id("rule") then
      n.height = line.height
      n.depth = line.depth
      width = n.width
    end
    n = n.next
  end
  return list, width
end

local function llap_wrap(list)
  -- Zero-width box: infinite glue pushes "list" flush to the right
  -- edge of the zero-width box (its own anchor point), so the content
  -- extends only leftward from there -- the same trick \llap uses.
  local hss = node.new("glue")
  hss.subtype = 0
  hss.width = 0
  hss.stretch = 65536
  hss.stretch_order = 2 -- fil
  hss.shrink = 0
  hss.shrink_order = 0
  hss.next = list
  list.prev = hss
  return node.hpack(hss, 0, "exactly")
end

local function decorate_line(line)
  local rule_list, width = clone_rule_for_line(line)
  -- The chain [lead-kern, rule, trail-kern] must net to zero width,
  -- since it lives inside a "to 0pt" box: the lead kern shifts left
  -- past the rule's own width plus the desired gap, the rule then
  -- draws back rightward by its width, and the trailing kern restores
  -- the remaining gap so the net displacement is zero.
  local lead = node.new("kern")
  lead.subtype = 1
  lead.kern = -(width + M.bar_gap)
  local trail = node.new("kern")
  trail.subtype = 1
  trail.kern = M.bar_gap
  lead.next = rule_list
  rule_list.prev = lead
  local tail = node.tail(rule_list)
  tail.next = trail
  trail.prev = tail
  local mark = llap_wrap(lead)
  mark.next = line.list
  if line.list then line.list.prev = mark end
  line.list = mark
end

luatexbase.add_to_callback("post_linebreak_filter", function(head)
  if not M.bar_active_box then return true end
  local n = head
  while n do
    if n.id == node.id("hlist") then
      decorate_line(n)
    end
    n = n.next
  end
  return true
end, "semcat.bar")

function M.bar_begin(boxnum)
  M.bar_active_box = boxnum
end

function M.bar_end()
  M.bar_active_box = nil
end

return M
--</lua>
