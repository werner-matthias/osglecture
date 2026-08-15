$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = [IO.Path]::GetFullPath(
  (Join-Path $PSScriptRoot '../..')
)
$baseTemp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$smokeRoot = Join-Path $baseTemp ("osglecture-install-" + [guid]::NewGuid().ToString('N'))
$texmfRoot = Join-Path $smokeRoot 'texmf'
$compileRoot = Join-Path $smokeRoot 'compile'

function Assert-NativeSuccess([string] $Description) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE"
  }
}

function Require-InstalledTeXFile([string] $Name) {
  $resolved = (& kpsewhich $Name | Select-Object -First 1).Trim()
  Assert-NativeSuccess "kpsewhich $Name"
  if (-not $resolved) {
    throw "Installed file is not visible to kpsewhich: $Name"
  }
  $resolvedPath = [IO.Path]::GetFullPath($resolved)
  $texmfPrefix = [IO.Path]::GetFullPath($script:texmfRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $resolvedPath.StartsWith($texmfPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "kpsewhich found $Name outside the smoke-test tree: $resolvedPath"
  }
  Write-Output ($Name.PadRight(38) + $resolvedPath)
}

New-Item -ItemType Directory -Force -Path $compileRoot | Out-Null

try {
  Set-Location $repositoryRoot
  & l3build install --texmfhome $texmfRoot
  Assert-NativeSuccess 'l3build install'

  $env:TEXMFHOME = $texmfRoot

  $texFiles = @(
    'osgdoc.cls',
    'osgdoc.sty',
    'langselect.sty',
    'ltxtalk-theme.sty',
    'ltxtalk-theme-tuc-2019.sty',
    'osglecture-modes.sty',
    'osglecture-modes-ltxtalk.sty',
    'osglecture-modes-ltxtalk.lua',
    'osglecture.cls',
    'osglecture-project.sty',
    'osglecture-structure.sty',
    'osglecture-adapter-beamer.def',
    'osglecture-profile-scrbook.def',
    'tagpax.sty',
    'tagpax-tagpdf-bridge.sty',
    'tagpax.lua',
    'tagpax-backend.lua'
  )
  foreach ($file in $texFiles) {
    Require-InstalledTeXFile $file
  }

  $ollmLauncher = Join-Path $texmfRoot 'scripts/osglecture/ollm.cmd'
  $ollmFiles = @(
    $ollmLauncher,
    (Join-Path $texmfRoot 'scripts/osglecture/lib/OLLM/Version.pm'),
    (Join-Path $texmfRoot 'scripts/osglecture/vendor/TOML-Tiny-0.22/lib/TOML/Tiny/Parser.pm'),
    (Join-Path $texmfRoot 'scripts/osglecture/definitions/bundle-presets/osg-lecture.toml')
  )
  foreach ($file in $ollmFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
      throw "Installed OLLM file is missing: $file"
    }
  }

  & $ollmLauncher --version
  Assert-NativeSuccess 'installed ollm.cmd'

  $cacheRoot = Join-Path $smokeRoot 'texmf-cache'
  New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
  $env:TEXMFCACHE = $cacheRoot
  $env:TEXMFVAR = $cacheRoot

  $source = @'
\documentclass[standalone,doctype=script]{osglecture}
\begin{document}
\lecture{Installation smoke test}{install-smoke}
Installed osglecture bundle.
\end{document}
'@
  $sourcePath = Join-Path $compileRoot 'install-smoke.tex'
  Set-Content -LiteralPath $sourcePath -Value $source -Encoding ascii

  Set-Location $compileRoot
  & lualatex -interaction=nonstopmode -halt-on-error install-smoke.tex
  Assert-NativeSuccess 'installed osglecture compilation'
  $pdf = Join-Path $compileRoot 'install-smoke.pdf'
  if (-not (Test-Path -LiteralPath $pdf -PathType Leaf) -or
      (Get-Item -LiteralPath $pdf).Length -eq 0) {
    throw 'Installation smoke test did not produce a non-empty PDF'
  }

  Set-Location $repositoryRoot
  & l3build uninstall --texmfhome $texmfRoot
  Assert-NativeSuccess 'l3build uninstall'

  $packageRoot = Join-Path $texmfRoot 'tex/luatex/osglecture'
  if ((Test-Path $packageRoot) -and
      (Get-ChildItem $packageRoot -File -Recurse | Select-Object -First 1)) {
    throw "l3build uninstall left package files behind in $packageRoot"
  }
  $scriptRoot = Join-Path $texmfRoot 'scripts/osglecture'
  if ((Test-Path $scriptRoot) -and
      (Get-ChildItem $scriptRoot -File -Recurse | Select-Object -First 1)) {
    throw "l3build uninstall left OLLM files behind in $scriptRoot"
  }

  Write-Output 'Installation smoke test passed.'
}
finally {
  Set-Location $repositoryRoot
  if (Test-Path -LiteralPath $smokeRoot) {
    Remove-Item -LiteralPath $smokeRoot -Recurse -Force
  }
}
