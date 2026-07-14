local process = require("build-support.process")
local M = {}
local unsupported = {
  { pattern='PDF2%.0 "AF" not supported', description='PDF 2.0 /AF is unsupported by this pdfcpu build' },
}
function M.available() return process.exists("pdfcpu") end
function M.validate(pdf,mode)
  if not M.available() then return true,"skipped","" end
  mode = mode or "strict"
  if mode == "s" then mode="strict" elseif mode == "r" then mode="relaxed" end
  assert(mode=="strict" or mode=="relaxed","invalid pdfcpu mode")
  local ok,out,code=process.capture("pdfcpu",{"validate",pdf,"--mode="..mode})
  if ok then if out~="" then io.write(out) end; return true,"passed",out,code end
  for _,u in ipairs(unsupported) do
    if out:match(u.pattern) then
      print("tagpax: UNSUPPORTED pdfcpu: "..u.description)
      return true,"unsupported",out,code
    end
  end
  if out~="" then io.write(out) end
  return false,"failed",out,code
end
return M
