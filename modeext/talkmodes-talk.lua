talkmodes_talk = talkmodes_talk or {}

talkmodes_talk.raw_skip_env = nil

local previous_callback = callback.find("process_input_buffer")

local function escape_pattern(s)
  return (s:gsub("([^%w])", "%%%1"))
end

function talkmodes_talk.start_raw_skip(env)
  talkmodes_talk.raw_skip_env = env
end

local function raw_skip_line(line)
  local env = talkmodes_talk.raw_skip_env
  if not env then
    return nil
  end

  local pattern =
    "^%s*\\end%s*{%s*" .. escape_pattern(env) .. "%s*}"

  if line:match(pattern) then
    talkmodes_talk.raw_skip_env = nil
  end

  return ""
end

local function process_input_buffer(line)
  local replacement = raw_skip_line(line)

  if replacement ~= nil then
    return replacement
  end

  if previous_callback then
    return previous_callback(line)
  end

  return nil
end

luatexbase.add_to_callback(
  "process_input_buffer",
  process_input_buffer,
  "talkmodes-talk raw skip"
)
