local process = require("build-support.process")
local M = {}
function M.available() return process.exists("verapdf") end
function M.validate(pdf,report)
  if not M.available() then return true,"skipped","" end
  local args={"--format","text",pdf}
  local ok,out,code=process.capture("verapdf",args)
  if report then local f=assert(io.open(report,"wb")); f:write(out); f:close() end
  if out~="" then io.write(out) end
  return ok,ok and "passed" or "failed",out,code
end
return M
