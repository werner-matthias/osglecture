-- Optional structural PDF checks:
--   l3build check -c structure
local validation = dofile("build-support/config-validation.lua")
local base_checkinit_hook = checkinit_hook

function checkinit_hook()
  local status = base_checkinit_hook and base_checkinit_hook() or 0
  if status ~= 0 then
    return status
  end

  local ok, pdf_or_error = validation.prepare_fixture("headings")
  if not ok then
    print("tagpax: " .. pdf_or_error)
    return 1
  end

  return validation.run_structure(pdf_or_error) and 0 or 1
end
