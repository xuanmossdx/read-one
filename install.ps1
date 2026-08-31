#Requires -Version 5.0
<#
.SYNOPSIS
  一键安装 read-one 到当前目录下的 read-one\
.DESCRIPTION
  从发行仓 Releases 下载最新主程序。仅保留实测可用源；安装包用浏览器链 + API 资源链双通道。
  失败持续重试直到成功（Ctrl+C 取消）。
  用法：
    irm https://raw.githubusercontent.com/xuanmossdx/read-one/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

$OwnerRepo = "xuanmossdx/read-one"
$ApiLatest = "https://api.github.com/repos/$OwnerRepo/releases/latest"
$ReleasesPage = "https://github.com/$OwnerRepo/releases"
$QqGroup = "1109580513"
$ApiTimeoutSec = 12
# 单源超时（并行）；整轮大约等于该值，避免 60 秒卡死还扫不完
$DownloadTimeoutSec = 25
$WaitSliceMs = 2000
$RetrySleepSec = 2
$MaxRetryRounds = 0

# 只保留近期实测能拉到真 zip / API 的前缀（过期站已剔除）
# 与 HttpMirrorClient 同步
$MirrorPrefixes = @(
  "https://gh-proxy.com/"
)

function Get-UrlHost([string]$Url) {
  try { return ([uri]$Url).Host } catch { return "unknown" }
}

function Get-MirroredUrls([string[]]$Urls) {
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($u in $Urls) {
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    $list.Add($u.Trim())
    foreach ($p in $MirrorPrefixes) {
      $list.Add(($p.TrimEnd("/") + "/" + $u.Trim()))
    }
  }
  return ,$list.ToArray()
}

function Start-HttpGetTask {
  param(
    [string]$Uri,
    [string]$OutFile,
    [int]$TimeoutSec,
    [string]$Accept
  )
  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
  [void]$client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", "read-one-install")
  if ($Accept) {
    [void]$client.DefaultRequestHeaders.TryAddWithoutValidation("Accept", $Accept)
  }

  if ($OutFile) {
    $task = $client.GetByteArrayAsync($Uri)
    return @{ Client = $client; Handler = $handler; Task = $task; OutFile = $OutFile; Uri = $Uri }
  }
  $task = $client.GetStringAsync($Uri)
  return @{ Client = $client; Handler = $handler; Task = $task; OutFile = $null; Uri = $Uri }
}

function Close-HttpItem($it) {
  if ($null -eq $it) { return }
  try { if ($it.Client) { $it.Client.CancelPendingRequests() } } catch {}
  try { if ($it.Client) { $it.Client.Dispose() } } catch {}
  try { if ($it.Handler) { $it.Handler.Dispose() } } catch {}
}

function Close-HttpItemList($list) {
  if ($null -eq $list) { return }
  foreach ($it in $list) { Close-HttpItem $it }
}

function Test-ReleaseJson([string]$text) {
  return ($text -and $text.Length -gt 50 -and $text -match '"tag_name"')
}

function Test-ZipBytes([byte[]]$bytes) {
  return ($bytes -and $bytes.Length -gt 10240 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)
}

function Get-AcceptForUrl([string]$Uri, [bool]$IsFile) {
  if (-not $IsFile) { return "application/vnd.github+json" }
  # API 资源下载必须用 octet-stream，否则只返回 JSON 元数据
  if ($Uri -match '/releases/assets/') { return "application/octet-stream" }
  return "*/*"
}

function Invoke-MirrorGetParallelOnce {
  param(
    [string[]]$Urls,
    [string]$OutFile = $null,
    [int]$TimeoutSec = 12,
    [string]$Purpose = "资源"
  )
  $expanded = Get-MirroredUrls $Urls
  Write-Host ("  并行尝试 {0} 个下载源（单源最多 {1} 秒）..." -f $expanded.Count, $TimeoutSec)

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($u in $expanded) {
    try {
      $acc = Get-AcceptForUrl -Uri $u -IsFile:([bool]$OutFile)
      [void]$items.Add((Start-HttpGetTask -Uri $u -OutFile $OutFile -TimeoutSec $TimeoutSec -Accept $acc))
    } catch {}
  }
  if ($items.Count -eq 0) { throw "无法创建网络请求" }

  $remaining = New-Object System.Collections.Generic.List[object]
  foreach ($it in $items) { [void]$remaining.Add($it) }

  $lastMsg = $null
  $started = [DateTime]::UtcNow
  $deadline = $started.AddSeconds($TimeoutSec + 2)
  $winnerResult = $null
  $winnerOk = $false
  $failCount = 0

  while ($remaining.Count -gt 0) {
    $taskArr = New-Object 'System.Threading.Tasks.Task[]' $remaining.Count
    for ($i = 0; $i -lt $remaining.Count; $i++) { $taskArr[$i] = $remaining[$i].Task }
    $msLeft = [int]([Math]::Max(200, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
    $waitMs = [Math]::Min($script:WaitSliceMs, $msLeft)
    $idx = [System.Threading.Tasks.Task]::WaitAny($taskArr, $waitMs)
    if ($idx -lt 0) {
      if ([DateTime]::UtcNow -ge $deadline) {
        # 取消剩余，避免挂死
        foreach ($it in $remaining) {
          try { $it.Client.CancelPendingRequests() } catch {}
        }
        Write-Host "  本轮超时，已取消剩余源"
        break
      }
      $elapsed = [int]([DateTime]::UtcNow - $started).TotalSeconds
      Write-Host ("  仍在等待... 剩余 {0} 个源，已等待 {1}/{2} 秒" -f $remaining.Count, $elapsed, $TimeoutSec)
      continue
    }

    $winner = $remaining[$idx]
    [void]$remaining.RemoveAt($idx)
    $hostName = Get-UrlHost $winner.Uri

    try {
      if ($winner.Task.IsFaulted) {
        $ex = $winner.Task.Exception.GetBaseException()
        $lastMsg = $ex.Message
        $failCount++
        Write-Host ("  失败 [{0}]（累计 {1}）" -f $hostName, $failCount)
      } elseif ($winner.Task.IsCanceled) {
        $lastMsg = "已取消或超时"
        $failCount++
        Write-Host ("  超时 [{0}]（累计 {1}）" -f $hostName, $failCount)
      } else {
        $result = $winner.Task.Result
        if ($OutFile) {
          $bytes = [byte[]]$result
          if (-not (Test-ZipBytes $bytes)) {
            $failCount++
            $lastMsg = "无效安装包"
            Write-Host ("  无效文件 [{0}] len={1}（累计 {2}）" -f $hostName, $(if ($bytes) { $bytes.Length } else { 0 }), $failCount)
          } else {
            [IO.File]::WriteAllBytes($OutFile, $bytes)
            Write-Host ("  下载成功 [{0}]" -f $hostName)
            $winnerOk = $true
            $winnerResult = $true
            break
          }
        } else {
          $text = [string]$result
          if (-not (Test-ReleaseJson $text)) {
            $failCount++
            $lastMsg = "无效版本信息"
            Write-Host ("  无效数据 [{0}]（累计 {1}）" -f $hostName, $failCount)
          } else {
            Write-Host ("  获取成功 [{0}]" -f $hostName)
            $winnerOk = $true
            $winnerResult = $text
            break
          }
        }
      }
    } catch {
      $lastMsg = $_.Exception.Message
      $failCount++
      Write-Host ("  失败 [{0}]（累计 {1}）" -f $hostName, $failCount)
    } finally {
      Close-HttpItem $winner
    }
  }

  Close-HttpItemList $remaining
  Close-HttpItemList $items

  if ($winnerOk) { return $winnerResult }
  $hint = "无法获取${Purpose}：本轮可用源均未成功。"
  if ($lastMsg) { throw ($hint + " 详情：" + $lastMsg) }
  throw $hint
}

function Invoke-MirrorGetParallel {
  param(
    [string[]]$Urls,
    [string]$OutFile = $null,
    [int]$TimeoutSec = 12,
    [string]$Purpose = "资源"
  )
  $round = 0
  while ($true) {
    $round++
    Write-Host (">>> 第 {0} 轮：获取{1}" -f $round, $Purpose)
    try {
      return Invoke-MirrorGetParallelOnce -Urls $Urls -OutFile $OutFile -TimeoutSec $TimeoutSec -Purpose $Purpose
    } catch {
      $msg = $_.Exception.Message
      Write-Host ("  本轮失败：{0}" -f $msg) -ForegroundColor Yellow
      if ($script:MaxRetryRounds -gt 0 -and $round -ge $script:MaxRetryRounds) {
        throw ("已重试 {0} 轮仍失败。手动下载：{1}`nQQ 群：{2}`n{3}" -f $round, $script:ReleasesPage, $script:QqGroup, $msg)
      }
      Write-Host ("  {0} 秒后重试（Ctrl+C 取消）..." -f $script:RetrySleepSec)
      Start-Sleep -Seconds $script:RetrySleepSec
    }
  }
}

function Test-Net472 {
  try {
    $rel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop).Release
    return ([int]$rel -ge 461808)
  } catch { return $false }
}

function Wait-ExitPause {
  param([int]$Code = 0)
  if ([Environment]::UserInteractive) {
    Write-Host ""
    Write-Host "按 Enter 键关闭..." -ForegroundColor Yellow
    try { [void](Read-Host) } catch {}
  }
  exit $Code
}

try {
  $InstallRoot = Join-Path (Get-Location).Path "read-one"
  Write-Host "安装目录：$InstallRoot"

  Write-Host "正在获取最新版本信息..."
  $json = Invoke-MirrorGetParallel -Urls @($ApiLatest) -TimeoutSec $ApiTimeoutSec -Purpose "版本信息"
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
    throw "Release 中未找到主程序压缩包。请手动下载：$ReleasesPage"
  }

  $work = Join-Path $env:TEMP ("read-one-install-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $work | Out-Null
  $zip = Join-Path $work "main.zip"
  # 双通道：浏览器下载链 + API 资源链（后者常比 github.com/releases/download 更稳）
  $dlUrls = @($main.browser_download_url, $main.url) | Where-Object { $_ } | Select-Object -Unique
  Write-Host "已找到 $tag，正在下载 $($main.name)..."
  Invoke-MirrorGetParallel -Urls $dlUrls -OutFile $zip -TimeoutSec $DownloadTimeoutSec -Purpose "主程序安装包" | Out-Null
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

  Write-Host "正在复制程序文件（保留已有用户数据）..."
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
    Write-Host "未检测到 .NET 4.7.2，正在下载运行库包..."
    $runtime = $assets | Where-Object { $_.name -match 'runtime' -and $_.name -like '*.zip' } | Select-Object -First 1
    if ($runtime) {
      $rz = Join-Path $work "runtime.zip"
      $rUrls = @($runtime.browser_download_url, $runtime.url) | Where-Object { $_ } | Select-Object -Unique
      Invoke-MirrorGetParallel -Urls $rUrls -OutFile $rz -TimeoutSec $DownloadTimeoutSec -Purpose "运行库安装包" | Out-Null
      $re = Join-Path $work "runtime"
      New-Item -ItemType Directory -Path $re | Out-Null
      Expand-Archive -Path $rz -DestinationPath $re -Force
      $setup = Get-ChildItem -Path $re -Filter "NDP472*.exe" -Recurse | Select-Object -First 1
      $bat = Get-ChildItem -Path $re -Filter "Install-Runtime.bat" -Recurse | Select-Object -First 1
      if ($setup) {
        Write-Host "正在安装运行库（可能弹出 UAC 提示）..."
        $p = Start-Process -FilePath $setup.FullName -Wait -PassThru
        Write-Host ("运行库安装退出码：" + $p.ExitCode)
      } elseif ($bat) {
        Start-Process -FilePath $bat.FullName -Wait
      } else {
        Write-Warning "运行库包内未找到安装程序，请手动安装 .NET Framework 4.7.2。"
      }
    } else {
      Write-Warning "Release 无运行库包。请先安装 .NET Framework 4.7.2，再运行 Start.bat。$ReleasesPage"
    }
  }

  Write-Host ""
  Write-Host "安装完成：$InstallRoot"
  Write-Host "请运行：$InstallRoot\Start.bat"
  Write-Host "QQ 群：$QqGroup"
  try { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
} catch {
  Write-Host ""
  Write-Host "安装失败：" -ForegroundColor Red
  Write-Host $_.Exception.Message
  Write-Host ""
  Write-Host "手动下载：$ReleasesPage"
  Write-Host "QQ 群：$QqGroup"
  Wait-ExitPause -Code 1
}
