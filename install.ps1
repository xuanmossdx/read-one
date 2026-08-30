#Requires -Version 5.0
<#
.SYNOPSIS
  一键安装 read-one 到当前目录下的 read-one\
.DESCRIPTION
  从本仓库 Releases 下载最新主程序；若本机缺少 .NET Framework 4.7.2 再安装运行库。
  用法（在目标文件夹打开 PowerShell）：
    irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OwnerRepo = "xuanmossdx/read-one"
$ApiLatest = "https://api.github.com/repos/$OwnerRepo/releases/latest"
$ReleasesPage = "https://github.com/$OwnerRepo/releases"
$QqGroup = "1109580513"
# 单次请求超时（秒）：连不上时快速失败并换源，避免一直卡住
$ApiTimeoutSec = 10
$DownloadTimeoutSec = 90
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

function Invoke-HttpGet {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [string]$OutFile = $null,
    [int]$TimeoutSec = 10
  )
  Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  try {
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    $client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", "read-one-install") | Out-Null
    $client.DefaultRequestHeaders.TryAddWithoutValidation("Accept", "application/vnd.github+json") | Out-Null
    if ($OutFile) {
      $bytes = $client.GetByteArrayAsync($Uri).GetAwaiter().GetResult()
      [IO.File]::WriteAllBytes($OutFile, $bytes)
      return $true
    }
    return $client.GetStringAsync($Uri).GetAwaiter().GetResult()
  } finally {
    $client.Dispose()
    $handler.Dispose()
  }
}

function Invoke-MirrorGet([string]$Url, [string]$OutFile = $null, [int]$TimeoutSec = 10, [string]$Purpose = "请求") {
  $urls = Get-MirroredUrls $Url
  $lastMsg = $null
  $total = $urls.Count
  $n = 0
  foreach ($u in $urls) {
    $n++
    $label = if ($n -lt $total) { "加速节点 $n" } else { "GitHub 直连" }
    Write-Host ("  [{0}/{1}] {2}（最多等待 {3} 秒）..." -f $n, $total, $label, $TimeoutSec)
    try {
      if ($OutFile) {
        Invoke-HttpGet -Uri $u -OutFile $OutFile -TimeoutSec $TimeoutSec | Out-Null
        Write-Host ("  [{0}/{1}] 成功" -f $n, $total)
        return $true
      } else {
        $text = Invoke-HttpGet -Uri $u -TimeoutSec $TimeoutSec
        Write-Host ("  [{0}/{1}] 成功" -f $n, $total)
        return $text
      }
    } catch {
      $msg = $_.Exception.Message
      if ($_.Exception.InnerException) {
        $msg = $_.Exception.InnerException.Message
      }
      # TaskCanceledException => 超时
      if ($msg -match 'canceled|cancelled|Timeout|超时|timed out|Unable to connect|无法连接|actively refused|Name or service|解析') {
        Write-Host ("  [{0}/{1}] 连不上或超时，换下一个" -f $n, $total)
      } else {
        Write-Host ("  [{0}/{1}] 失败，换下一个" -f $n, $total)
      }
      $lastMsg = $msg
    }
  }
  $hint = @"
无法获取$Purpose：加速节点与 GitHub 均连不上（已逐个超时跳过）。

请检查网络后重试，或手动打开下载：
$ReleasesPage

QQ 群：$QqGroup
"@
  if ($lastMsg) {
    throw ($hint + "`n技术详情: " + $lastMsg)
  }
  throw $hint
}

function Test-Net472 {
  try {
    $rel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
    return ([int]$rel -ge 461808)
  } catch {
    return $false
  }
}

try {
  $InstallRoot = Join-Path (Get-Location).Path "read-one"
  Write-Host "安装目录: $InstallRoot"

  Write-Host "正在获取最新版本（优先国内加速，失败则直连 GitHub）..."
  $json = Invoke-MirrorGet -Url $ApiLatest -TimeoutSec $ApiTimeoutSec -Purpose "版本信息"
  $release = $json | ConvertFrom-Json
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
  Write-Host "已找到 $tag，正在下载 $($main.name)..."
  Invoke-MirrorGet -Url $main.browser_download_url -OutFile $zip -TimeoutSec $DownloadTimeoutSec -Purpose "主程序安装包" | Out-Null
  Write-Host "下载完成，正在安装..."

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
      Invoke-MirrorGet -Url $runtime.browser_download_url -OutFile $rz -TimeoutSec $DownloadTimeoutSec -Purpose "运行库安装包" | Out-Null
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
  Write-Host "QQ 群（获取最新版 / 交流）：$QqGroup"
  try { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
} catch {
  Write-Host ""
  Write-Host "安装失败：" -ForegroundColor Red
  Write-Host $_.Exception.Message
  Write-Host ""
  Write-Host "手动下载: $ReleasesPage"
  Write-Host "QQ 群: $QqGroup"
  exit 1
}
