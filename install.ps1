#Requires -Version 5.0
<#
.SYNOPSIS
  Install read-one into .\read-one\
.DESCRIPTION
  Download latest release; install .NET Framework 4.7.2 only if missing.
  Multiple CN mirrors race in parallel; first success wins.
  Usage (PowerShell in target folder):
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
$DownloadTimeoutSec = 90

# Keep in sync with HttpMirrorClient
$MirrorPrefixes = @(
  "https://ghfast.top/",
  "https://gh-proxy.com/",
  "https://ghproxy.net/",
  "https://mirror.ghproxy.com/",
  "https://hub.gitmirror.com/",
  "https://ghproxy.homeboyc.cn/",
  "https://github.akams.cn/"
)

function Get-MirroredUrls([string]$Url) {
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($p in $MirrorPrefixes) {
    $list.Add(($p.TrimEnd("/") + "/" + $Url))
  }
  $list.Add($Url)
  return ,$list.ToArray()
}

function Start-HttpGetTask {
  param(
    [string]$Uri,
    [string]$OutFile,
    [int]$TimeoutSec
  )
  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
  [void]$client.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", "read-one-install")
  [void]$client.DefaultRequestHeaders.TryAddWithoutValidation("Accept", "application/vnd.github+json")

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
  # Do NOT wrap List[object] with @() — PowerShell throws "参数类型不匹配"
  if ($null -eq $list) { return }
  foreach ($it in $list) {
    Close-HttpItem $it
  }
}

function Invoke-MirrorGetParallel {
  param(
    [string]$Url,
    [string]$OutFile = $null,
    [int]$TimeoutSec = 12,
    [string]$Purpose = "request"
  )
  $urls = Get-MirroredUrls $Url
  Write-Host ("  Racing {0} sources (timeout {1}s each)..." -f $urls.Count, $TimeoutSec)

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($u in $urls) {
    try {
      [void]$items.Add((Start-HttpGetTask -Uri $u -OutFile $OutFile -TimeoutSec $TimeoutSec))
    } catch {
      # ignore create failure
    }
  }
  if ($items.Count -eq 0) {
    throw "Could not create HTTP requests"
  }

  $remaining = New-Object System.Collections.Generic.List[object]
  foreach ($it in $items) { [void]$remaining.Add($it) }

  $lastMsg = $null
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec + 3)
  $winnerResult = $null
  $winnerOk = $false

  while ($remaining.Count -gt 0) {
    $taskArr = New-Object 'System.Threading.Tasks.Task[]' $remaining.Count
    for ($i = 0; $i -lt $remaining.Count; $i++) {
      $taskArr[$i] = $remaining[$i].Task
    }
    $msLeft = [int]([Math]::Max(200, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
    $idx = [System.Threading.Tasks.Task]::WaitAny($taskArr, $msLeft)
    if ($idx -lt 0) {
      Write-Host "  All sources timed out"
      break
    }

    $winner = $remaining[$idx]
    [void]$remaining.RemoveAt($idx)

    try {
      if ($winner.Task.IsFaulted) {
        $ex = $winner.Task.Exception.GetBaseException()
        $lastMsg = $ex.Message
        Write-Host "  Source failed, waiting for others..."
      } elseif ($winner.Task.IsCanceled) {
        $lastMsg = "canceled/timeout"
        Write-Host "  Source timed out, waiting for others..."
      } else {
        $result = $winner.Task.Result
        if ($OutFile) {
          [IO.File]::WriteAllBytes($OutFile, [byte[]]$result)
          Write-Host "  Download OK"
          $winnerOk = $true
          $winnerResult = $true
          break
        } else {
          Write-Host "  Fetch OK"
          $winnerOk = $true
          $winnerResult = [string]$result
          break
        }
      }
    } catch {
      $lastMsg = $_.Exception.Message
      Write-Host "  Source failed, waiting for others..."
    } finally {
      Close-HttpItem $winner
    }
  }

  Close-HttpItemList $remaining
  Close-HttpItemList $items

  if ($winnerOk) {
    return $winnerResult
  }

  $hint = @"
Failed to get ${Purpose}: mirrors and GitHub unreachable (parallel race timed out).

Check network and retry, or download manually:
$ReleasesPage

QQ group: $QqGroup
"@
  if ($lastMsg) { throw ($hint + "`nDetail: " + $lastMsg) }
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

function Wait-ExitPause {
  param([int]$Code = 0)
  if ([Environment]::UserInteractive) {
    Write-Host ""
    Write-Host "Press Enter to close..." -ForegroundColor Yellow
    try { [void](Read-Host) } catch {}
  }
  exit $Code
}

try {
  $InstallRoot = Join-Path (Get-Location).Path "read-one"
  Write-Host "Install dir: $InstallRoot"

  Write-Host "Fetching latest release (parallel mirrors)..."
  $json = Invoke-MirrorGetParallel -Url $ApiLatest -TimeoutSec $ApiTimeoutSec -Purpose "release info"
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
    throw "No main zip in Release. Manual download: $ReleasesPage"
  }

  $work = Join-Path $env:TEMP ("read-one-install-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $work | Out-Null
  $zip = Join-Path $work "main.zip"
  Write-Host "Found $tag, downloading $($main.name)..."
  Invoke-MirrorGetParallel -Url $main.browser_download_url -OutFile $zip -TimeoutSec $DownloadTimeoutSec -Purpose "main package" | Out-Null
  Write-Host "Download done, installing..."

  $extract = Join-Path $work "extract"
  New-Item -ItemType Directory -Path $extract | Out-Null
  Expand-Archive -Path $zip -DestinationPath $extract -Force

  $pkg = $extract
  if (-not (Test-Path (Join-Path $pkg "read-one.exe"))) {
    $found = Get-ChildItem -Path $extract -Filter "read-one.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $pkg = $found.DirectoryName }
  }
  if (-not (Test-Path (Join-Path $pkg "read-one.exe"))) {
    throw "read-one.exe not found after extract"
  }

  if (-not (Test-Path $InstallRoot)) {
    New-Item -ItemType Directory -Path $InstallRoot | Out-Null
  }

  Write-Host "Copying files (keeping user data)..."
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
    Write-Host ".NET Framework 4.7.2+ detected, skip runtime install."
  } else {
    Write-Host ".NET 4.7.2 missing, downloading runtime package..."
    $runtime = $assets | Where-Object { $_.name -match 'runtime' -and $_.name -like '*.zip' } | Select-Object -First 1
    if ($runtime) {
      $rz = Join-Path $work "runtime.zip"
      Invoke-MirrorGetParallel -Url $runtime.browser_download_url -OutFile $rz -TimeoutSec $DownloadTimeoutSec -Purpose "runtime package" | Out-Null
      $re = Join-Path $work "runtime"
      New-Item -ItemType Directory -Path $re | Out-Null
      Expand-Archive -Path $rz -DestinationPath $re -Force
      $setup = Get-ChildItem -Path $re -Filter "NDP472*.exe" -Recurse | Select-Object -First 1
      $bat = Get-ChildItem -Path $re -Filter "Install-Runtime.bat" -Recurse | Select-Object -First 1
      if ($setup) {
        Write-Host "Installing runtime (UAC may appear)..."
        $p = Start-Process -FilePath $setup.FullName -Wait -PassThru
        Write-Host ("Runtime exit code: " + $p.ExitCode)
      } elseif ($bat) {
        Start-Process -FilePath $bat.FullName -Wait
      } else {
        Write-Warning "Runtime package has no installer. Please install .NET Framework 4.7.2 manually."
      }
    } else {
      Write-Warning "No runtime zip in Release. Install .NET Framework 4.7.2 then run Start.bat. $ReleasesPage"
    }
  }

  Write-Host ""
  Write-Host "Done: $InstallRoot"
  Write-Host "Run: $InstallRoot\Start.bat"
  Write-Host "QQ group: $QqGroup"
  try { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
} catch {
  Write-Host ""
  Write-Host "Install failed:" -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($_.ScriptStackTrace) {
    Write-Host ""
    Write-Host $_.ScriptStackTrace
  }
  Write-Host ""
  Write-Host "Manual download: $ReleasesPage"
  Write-Host "QQ group: $QqGroup"
  Wait-ExitPause -Code 1
}
