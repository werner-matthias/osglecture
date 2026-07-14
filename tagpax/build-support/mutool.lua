local process = require("build-support.process")
local M = {}
function M.available() return process.exists("mutool") end
function M.validate(pdf)
  if not M.available() then return true,"skipped","" end
  local ok,out,code=process.capture("mutool",{"info",pdf})
  return ok,ok and "passed" or "failed",out,code
end
return M
