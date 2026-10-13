param(
 [Parameter(Mandatory=$true)][string]$RunDirectory,
 [Parameter(Mandatory=$true)][string]$ResultDirectory
)
# One finite experiment pipeline, no scheduler/recurring automation or new jobs.
$ErrorActionPreference='Stop'
$taskWorkspace=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskWorkspace
$taskRun=(Resolve-Path -LiteralPath $RunDirectory).Path
$taskOut=[System.IO.Path]::GetFullPath((Join-Path $taskWorkspace $ResultDirectory))
$taskComplete=Join-Path $taskRun 'COMPLETED.json'
Write-Output 'Waiting for the already running frozen ablation batch to finish.'
while (-not (Test-Path -LiteralPath $taskComplete)) {
 $taskProgress=Join-Path $taskRun 'progress.json'
 if (Test-Path -LiteralPath $taskProgress) {
  try { $taskState=Get-Content -LiteralPath $taskProgress -Raw | ConvertFrom-Json } catch { $taskState=$null }
  if ($null -ne $taskState -and $taskState.Failed -gt 0) { throw 'Batch has failures; no completion analysis.' }
 }
 $taskRunning=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'MATLAB.exe' -and $_.CommandLine -like '*run_saq_sparse_ablation_30seed*' })
 if ($taskRunning.Count -eq 0) { throw 'Experiment process stopped without complete marker. Inspect progress; resume via run_saq_sparse_ablation_30seed.' }
 Start-Sleep -Seconds 15
}
Write-Output 'Optimization complete. Running independent MAT validation and predefined comparisons.'
& python (Join-Path $PSScriptRoot 'analyze_saq_sparse_ablation.py') $taskRun --out $taskOut
if ($LASTEXITCODE -ne 0) { throw 'Independent artifact analysis failed; report not accepted.' }
# MATLAB strings use single-quote doubling, never shell command construction.
$taskMRun=$taskRun.Replace("'","''");$taskMOut=$taskOut.Replace("'","''")
$taskBatch="addpath(pwd);addpath(fullfile(pwd,'experiments'));setup_project(true);verify_saq_sparse_ablation_best('$taskMRun','$taskMOut');"
& matlab -batch $taskBatch
if ($LASTEXITCODE -ne 0) { throw 'Independent MATLAB recheck failed.' }
$taskAccepted=Get-Content -LiteralPath (Join-Path $taskOut 'independent_matlab_recheck.json') -Raw | ConvertFrom-Json
if (-not $taskAccepted.Passed) { throw 'Final objective audit did not pass.' }
[pscustomobject]@{Complete=$true;QualityRecords=5220;NewRuns=4350;CachedFullRuns=870;Passed=$true;Finished=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss');ResultDirectory=$taskOut} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOut 'ACCEPTED.json') -Encoding utf8
Write-Output "Accepted all artifact checks. Results: $taskOut"
