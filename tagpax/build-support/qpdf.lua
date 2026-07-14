local process = require("build-support.process")
local M = {}
function M.available() return process.exists("qpdf") end
function M.validate(pdf)
  if not M.available() then return true,"skipped","" end
  local ok,out,code=process.capture("qpdf",{"--check",pdf})
  if out~="" then io.write(out) end
  return ok,ok and "passed" or "failed",out,code
end
return M
