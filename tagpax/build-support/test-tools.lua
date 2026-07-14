package.path = "./?.lua;./?/init.lua;" .. package.path
local tools = require("build-support.tools")
assert(type(tools.process.quote("a b"))=="string")
assert(type(tools.qpdf.available())=="boolean")
assert(type(tools.pdfcpu.available())=="boolean")
print("tagpax build tools: ok")
