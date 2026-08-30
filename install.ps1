#Requires -Version 5.0
<#
.SYNOPSIS
  一键安装 read-one 到当前目录下的 read-one\
.NOTES
  发行仓同步本脚本到仓库根后，用户可：
    irm https://ghfast.top/https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
  或直连：
    irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OwnerRepo = "xuanmossdx/read-one"
$ApiLatest = "https://api.github.com/repos/$OwnerRepo/releases/latest"
$ReleasesPage = "https://github.com/$OwnerRepo/releases"
$MirrorPrefixes = @(
  "https://ghfast.top/",
  "https://ghproxy.net/",
  "https://mirror.ghproxy.com/"
)

function Get-MirroredUrls([string]$Url) {
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($p in $MirrorPrefixes) {
    $list.Add(($p.TrimEnd("/") + "/" + $Url))
  }
  $list.Add($Url)
  return ,$list.ToArray()
}

function Invoke-MirrorGet([string]$Url, [string]$OutFile = $null) {
  $urls = Get-MirroredUrls $Url
  $last = $null
  foreach ($u in $urls) {
    try {
      Write-Host "尝试: $u"
      if ($OutFile) {
        Invoke-WebRequest -Uri $u -OutFile $OutFile -UseBasicParsing -Headers @{ "User-Agent" = "read-one-install" }
      } else {
        return (Invoke-RestMethod -Uri $u -Headers @{ "User-Agent" = "read-one-install"; "Accept" = "application/vnd.github+json" })
      }
      return $true
    } catch {
      $last = $_
      Write-Host ("失败: " + $_.Exception.Message)
    }
  }
  if ($last) { throw $last }
  throw "全部源失败: $Url"
}

function Test-Net472 {
  try {
    $rel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
    return ([int]$rel -ge 461808)
  } catch {
    return $false
  }
}

$InstallRoot = Join-Path (Get-Location).Path "read-one"
Write-Host "安装目录: $InstallRoot"

Write-Host "查询最新 Release..."
$release = Invoke-MirrorGet $ApiLatest
$tag = $release.tag_name
$assets = @($release.assets)
$main = $assets | Where-Object {
  $_.name -match '^read-one-v.+\.zip$' -and ($_.name -notmatch 'runtime')
} | Select-Object -First 1
if (-not $main) {
  $main = $assets | Where-Object {
    $_.name -like 'read-one*.zip' -and ($_.name -notmatch 'runtime')
  } | Select-Object -First 1
}
if (-not $main) {
  throw "Release 中未找到主包 zip。请手动下载: $ReleasesPage"
}

$work = Join-Path $env:TEMP ("read-one-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$zip = Join-Path $work "main.zip"
Write-Host "下载主包 $($main.name) ($tag)..."
Invoke-MirrorGet $main.browser_download_url $zip | Out-Null

$extract = Join-Path $work "extract"
New-Item -ItemType Directory -Path $extract | Out-Null
Expand-Archive -Path $zip -DestinationPath $extract -Force

$pkg = $extract
if (-not (Test-Path (Join-Path $pkg "read-one.exe"))) {
  $found = Get-ChildItem -Path $extract -Filter "read-one.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $pkg = $found.DirectoryName }
}
if (-not (Test-Path (Join-Path $pkg "read-one.exe"))) {
  throw "解压后未找到 read-one.exe"
}

if (-not (Test-Path $InstallRoot)) {
  New-Item -ItemType Directory -Path $InstallRoot | Out-Null
}

Write-Host "复制程序文件（保留已有用户数据）..."
$keepNames = @("db5.data", "log.txt", "ai-presets-custom.json")
Get-ChildItem -Path $pkg -File | ForEach-Object {
  if ($keepNames -contains $_.Name) { return }
  Copy-Item $_.FullName (Join-Path $InstallRoot $_.Name) -Force
}
$libSrc = Join-Path $pkg "lib"
if (Test-Path $libSrc) {
  $libDst = Join-Path $InstallRoot "lib"
  if (-not (Test-Path $libDst)) { New-Item -ItemType Directory -Path $libDst | Out-Null }
  Copy-Item (Join-Path $libSrc "*") $libDst -Force -Recurse
}

if (Test-Net472) {
  Write-Host "已检测到 .NET Framework 4.7.2+，跳过运行库安装。"
} else {
  Write-Host "未检测到 .NET 4.7.2，尝试下载运行库包..."
  $runtime = $assets | Where-Object { $_.name -match 'runtime' -and $_.name -like '*.zip' } | Select-Object -First 1
  if ($runtime) {
    $rz = Join-Path $work "runtime.zip"
    Invoke-MirrorGet $runtime.browser_download_url $rz | Out-Null
    $re = Join-Path $work "runtime"
    New-Item -ItemType Directory -Path $re | Out-Null
    Expand-Archive -Path $rz -DestinationPath $re -Force
    $setup = Get-ChildItem -Path $re -Filter "NDP472*.exe" -Recurse | Select-Object -First 1
    $bat = Get-ChildItem -Path $re -Filter "Install-Runtime.bat" -Recurse | Select-Object -First 1
    if ($setup) {
      Write-Host "正在安装运行库（可能弹出 UAC）..."
      $p = Start-Process -FilePath $setup.FullName -Wait -PassThru
      Write-Host ("运行库安装退出码: " + $p.ExitCode)
    } elseif ($bat) {
      Start-Process -FilePath $bat.FullName -Wait
    } else {
      Write-Warning "运行库包内未找到安装程序，请手动安装 .NET Framework 4.7.2。"
    }
  } else {
    Write-Warning "Release 无运行库包。请安装 .NET Framework 4.7.2 后运行 Start.bat。$ReleasesPage"
  }
}

Write-Host ""
Write-Host "安装完成: $InstallRoot"
Write-Host "请运行: $InstallRoot\Start.bat"
try { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
