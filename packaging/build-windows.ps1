$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $iscc = if ($compiler) { $compiler.Source } else {
        @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
          "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
          "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (!$iscc) { throw 'Install Inno Setup 6 and run this script again.' }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vs) { throw 'Install Visual Studio with Desktop development with C++.' }
    $crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory |
        Sort-Object { [version]$_.Parent.Parent.Name } -Descending | Select-Object -First 1
    if (!$crt) { throw 'Install the x64 Visual C++ redistributable files in Visual Studio Installer.' }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'The Flutter Windows release build failed.' }
    $manifest = Get-Content pubspec.yaml -Raw
    if ($manifest -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') { throw 'Missing app version in pubspec.yaml.' }
    & $iscc "/DAppVersion=$($Matches[1])" "/DCRTRoot=$($crt.FullName)" packaging\oyudent.iss
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer packaging failed.' }
    Get-ChildItem build\installers\Oyudent-POS-*-windows-x64.exe
} finally {
    Pop-Location
}
