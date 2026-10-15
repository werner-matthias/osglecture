-- Bibliography tests need biber between the LaTeX runs: run 1 writes the
-- .bcf, biber resolves it, run 2 prints the entries and records them in the
-- .aux, run 3 sets the citation links from that record.
testfiledir = "./testfiles-bibliography"
-- Shares the support files of the main tests.  Not written as
-- "./testfiles/support": l3build resets exactly that default to
-- <testfiledir>/support after loading a configuration.
testsuppdir = "testfiles/support"
checkruns = 3
checksuppfiles = { }

function runtest_tasks(name, run)
  if run == 1 then
    return "biber --quiet " .. name
  end
  return ""
end
