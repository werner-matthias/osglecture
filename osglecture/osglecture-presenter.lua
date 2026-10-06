-- osglecture-presenter.lua: node and PDF-object helpers for
-- osglecture-presenter.sty.
local M = {}

local whatsit = node.id("whatsit")
local keep = {}
for _, name in ipairs { "pdf_literal", "pdf_colorstack", "pdf_setmatrix",
                        "pdf_save", "pdf_restore" } do
  keep[node.subtype(name)] = true
end

-- The slide copy becomes a form XObject. Anything that writes to a file,
-- sets a destination or opens an annotation would do so a second time (or is
-- not allowed inside a form at all), so only the whatsits that carry drawing
-- state survive.
local function strip(box)
  local n = box.head
  while n do
    local next = n.next
    if n.id == whatsit then
      if not keep[n.subtype] then
        box.head = node.remove(box.head, n)
        node.free(n)
      end
    elseif n.head then
      strip(n)
    end
    n = next
  end
end

function M.strip(number)
  local box = tex.box[number]
  if box then strip(box) end
end

-- The preview of the next slide is a forward reference: the panel of page k
-- paints a form whose object number is reserved now and filled in when page
-- k+1 has been captured.
local pending

function M.reserve()
  pending = pdf.reserveobj()
  tex.sprint(pending)
end

local function forward(number, target, width, height)
  local bp = 65781.76
  local attr = string.format(
    "/Type/XObject/Subtype/Form/BBox[0 0 %.4f %.4f]", width / bp, height / bp)
  if target then
    pdf.immediateobj(number, "stream", "/Fm Do",
      attr .. string.format("/Resources<</XObject<</Fm %d 0 R>>>>", target))
  else
    pdf.immediateobj(number, "stream", "", attr)
  end
end

function M.resolve(target, width, height)
  if pending then
    forward(pending, target, width, height)
    pending = nil
  end
end

function M.finish(width, height)
  M.resolve(nil, width, height)
end

return M
