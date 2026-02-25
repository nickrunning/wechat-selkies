param(
    [string]$InputDir = "diagnostics/overnight",
    [int]$WindowSize = 7
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputDir)) {
    throw "Input directory not found: $InputDir"
}

$summaryFiles = Get-ChildItem -Path $InputDir -Recurse -Filter "summary.json" |
    Sort-Object FullName

if ($summaryFiles.Count -eq 0) {
    throw "No summary.json files found in $InputDir"
}

$entries = @()
foreach ($file in $summaryFiles) {
    $data = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json
    $entries += [PSCustomObject]@{
        file = $file.FullName
        timestamp = [DateTime]$data.timestamp
        paused = [bool]$data.state.paused
        running = [bool]$data.state.running
        restartCount = [int]$data.state.restartCount
        lifecycleEventCount = [int]$data.lifecycleEventCount
        wechatProcessDetected = [bool]$data.wechatProcessDetected
        verdict = [string]$data.verdict
    }
}

$entries = $entries | Sort-Object timestamp
$window = $entries | Select-Object -Last $WindowSize

$restartCountIncreased = $false
for ($i = 1; $i -lt $window.Count; $i++) {
    if ($window[$i].restartCount -gt $window[$i - 1].restartCount) {
        $restartCountIncreased = $true
        break
    }
}

$notRunningCount = ($window | Where-Object { -not $_.running }).Count
$pausedCount = ($window | Where-Object { $_.paused }).Count
$lifecycleIssueCount = ($window | Where-Object { $_.lifecycleEventCount -gt 0 }).Count
$wechatProcessMissingCount = ($window | Where-Object { -not $_.wechatProcessDetected }).Count

$acceptancePass = ($window.Count -ge $WindowSize) -and `
    ($notRunningCount -eq 0) -and `
    ($pausedCount -eq 0) -and `
    (-not $restartCountIncreased)

$report = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    inputDir = (Resolve-Path $InputDir).Path
    windowSize = $WindowSize
    sampleCount = $window.Count
    acceptance = [ordered]@{
        pass = $acceptancePass
        criteria = "running=true, paused=false, restartCount not increasing across the window"
    }
    counts = [ordered]@{
        notRunning = $notRunningCount
        paused = $pausedCount
        lifecycleIssues = $lifecycleIssueCount
        wechatProcessMissing = $wechatProcessMissingCount
        restartCountIncreased = $restartCountIncreased
    }
    latestVerdicts = @($window | ForEach-Object {
        [ordered]@{
            timestamp = $_.timestamp.ToString("o")
            restartCount = $_.restartCount
            verdict = $_.verdict
            file = $_.file
        }
    })
}

$reportJson = $report | ConvertTo-Json -Depth 6
$reportPath = Join-Path $InputDir "seven-night-report.json"
Set-Content -Path $reportPath -Value $reportJson -Encoding UTF8

Write-Output "Report generated: $reportPath"
Write-Output "Acceptance pass: $acceptancePass"
