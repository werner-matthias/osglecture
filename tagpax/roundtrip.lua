-- l3build configuration for the live PDF roundtrip
local base_checkinit_hook = checkinit_hook
includetests = { "roundtrip" }
excludetests = { }
function checkinit_hook()
  local err = base_checkinit_hook and base_checkinit_hook() or 0
  if err ~= 0 then return err end
  local env={"TEXINPUTS","LUAINPUTS"}
  err=runcmd("lualatex -interaction=nonstopmode -halt-on-error '\\def\\InputPdf{subdocument.pdf}\\def\\OutputIr{subdocument.tagpax}\\input{extract-helper.tex}'",testdir,env)
  if err~=0 then return err end
  err=runcmd("lualatex -interaction=nonstopmode -halt-on-error roundtrip-master.tex",testdir,env)
  if err~=0 then return err end
  err=runcmd("lualatex -interaction=nonstopmode -halt-on-error roundtrip-master.tex",testdir,env)
  if err~=0 then return err end
  return runcmd("lualatex -interaction=nonstopmode -halt-on-error '\\def\\InputPdf{roundtrip-master.pdf}\\def\\OutputIr{roundtrip-master.tagpax}\\input{extract-helper.tex}'",testdir,env)
end
