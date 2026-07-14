-- Shared support for the optional l3build validation configurations.
local M = {}

package.path = "./?.lua;./?/init.lua;" .. package.path
local tools = require("build-support.tools")

local function mkdir(path)
  if package.config:sub(1, 1) == "\\" then
    return tools.process.run("cmd", { "/C", "mkdir", path }, { quiet = true }) == 0
  end
  return tools.process.run("mkdir", { "-p", path }, { quiet = true }) == 0
end

local function copy_file(source, target)
  local input, err = io.open(source, "rb")
  if not input then
    return false, err
  end
  local data = input:read("*a")
  input:close()

  local output, write_err = io.open(target, "wb")
  if not output then
    return false, write_err
  end
  output:write(data)
  output:close()
  return true
end

function M.prepare_fixture(name, destination)
  local output_dir = destination or "build/validate"
  if not mkdir(output_dir) then
    return false, "cannot create " .. output_dir
  end

  local source = "testfiles/support/" .. name .. ".tex"
  local copied = output_dir .. "/" .. name .. ".tex"
  local ok, err = copy_file(source, copied)
  if not ok then
    return false, "cannot copy fixture: " .. tostring(err)
  end

  local status = tools.process.run(
    "lualatex",
    {
      "-interaction=nonstopmode",
      "-halt-on-error",
      "-output-directory=" .. output_dir,
      copied,
    }
  )

  if status ~= 0 then
    return false, "fixture compilation failed"
  end

  return true, output_dir .. "/" .. name .. ".pdf"
end

function M.run_structure(pdf)
  tools.detect()

  local ok = true
  local qpdf_ok = select(1, tools.qpdf.validate(pdf))
  local mutool_ok = select(1, tools.mutool.validate(pdf))
  local pdfcpu_ok, pdfcpu_status = tools.pdfcpu.validate(pdf, "strict")

  ok = qpdf_ok and ok
  ok = mutool_ok and ok
  ok = pdfcpu_ok and ok

  if pdfcpu_status == "unsupported" then
    print("tagpax: pdfcpu result ignored for this known unsupported PDF 2.0 feature")
  end

  return ok
end

function M.run_verapdf(pdf, report)
  local ok, status = tools.verapdf.validate(pdf, report)
  if status == "skipped" then
    print("tagpax: veraPDF not available; PDF/UA validation skipped")
  end
  return ok
end

return M
