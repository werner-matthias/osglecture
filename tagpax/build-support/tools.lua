local M = {
  process = require("build-support.process"),
  qpdf = require("build-support.qpdf"),
  mutool = require("build-support.mutool"),
  pdfcpu = require("build-support.pdfcpu"),
  verapdf = require("build-support.verapdf"),
}
function M.detect()
  local names={"qpdf","mutool","pdfcpu","verapdf"}
  print("tagpax: external PDF tools")
  for _,name in ipairs(names) do
    print(string.format("tagpax:   %-8s %s",name,M[name].available() and "found" or "not found"))
  end
end
function M.structure(pdf)
  local ok=true
  local a=select(1,M.qpdf.validate(pdf)); ok=a and ok
  local b=select(1,M.mutool.validate(pdf)); ok=b and ok
  local c=select(1,M.pdfcpu.validate(pdf,"strict")); ok=c and ok
  return ok
end
return M
