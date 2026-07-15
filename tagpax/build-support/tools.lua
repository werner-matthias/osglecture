-- build-support/tools.lua -- external PDF tool integration for tagpax

local M = {}

local is_windows = package.config:sub(1, 1) == "\\"

local function status_code(a, b, c)
  -- Lua 5.1 commonly returns a numeric status; newer Lua versions return
  -- success, exit-kind and exit-code.
  if type(a) == "number" then
    return a
  end
  if a == true then
    return 0
  end
  if type(c) == "number" then
    return c
  end
  return 1
end

function M.quote(value)
  value = tostring(value)
  if is_windows then
    return '"' .. value:gsub('"', '\\"') .. '"'
  end
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

function M.command_exists(name)
  local command
  if is_windows then
    command = "where " .. M.quote(name) .. " >NUL 2>NUL"
  else
    command = "command -v " .. M.quote(name) .. " >/dev/null 2>&1"
  end
  return status_code(os.execute(command)) == 0
end

function M.run(program, arguments, options)
  arguments = arguments or {}
  options = options or {}

  local parts = { M.quote(program) }
  for _, argument in ipairs(arguments) do
    parts[#parts + 1] = M.quote(argument)
  end

  local command = table.concat(parts, " ")
  if options.stdout then
    command = command .. " > " .. M.quote(options.stdout)
  elseif options.quiet then
    command = command .. (is_windows and " >NUL" or " >/dev/null")
  end
  if options.stderr then
    command = command .. " 2> " .. M.quote(options.stderr)
  elseif options.quiet then
    command = command .. (is_windows and " 2>NUL" or " 2>/dev/null")
  end

  if not options.silent then
    print("tagpax: " .. command)
  end
  return status_code(os.execute(command))
end

function M.detect(programs)
  local result = {}
  for _, name in ipairs(programs) do
    result[name] = M.command_exists(name)
  end
  return result
end

function M.run_optional(program, arguments, options)
  if not M.command_exists(program) then
    print("tagpax: SKIP " .. program .. " (not installed or not on PATH)")
    return 0, false
  end
  return M.run(program, arguments, options), true
end

function M.print_detection(programs)
  local detected = M.detect(programs)
  print("tagpax: external PDF tools")
  for _, name in ipairs(programs) do
    print(string.format("tagpax:   %-8s %s", name, detected[name] and "found" or "not found"))
  end
  return detected
end

function M.qpdf(pdf)
  return M.run_optional("qpdf", { "--check", pdf })
end

function M.mutool(pdf)
  return M.run_optional("mutool", { "info", pdf }, { quiet = true })
end

function M.pdfcpu(pdf, mode)
  -- pdfcpu accepts the mode abbreviations r(elaxed) and s(trict).
  mode = mode or "s"
  return M.run_optional("pdfcpu", { "validate", "-mode", mode, pdf })
end

function M.verapdf(pdf, report)
  return M.run_optional(
    "verapdf",
    { "--format", "text", pdf },
    { stdout = report }
  )
end

return M
