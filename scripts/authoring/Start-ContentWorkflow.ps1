#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$Diagnostics,
	[switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workflow.Common.psm1') -Force

function Invoke-WorkflowPhase {
	param(
		[Parameter(Mandatory = $true)][string]$ScriptName,
		[hashtable]$Parameters = @{}
	)

	$scriptPath = Join-Path $PSScriptRoot $ScriptName
	if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
		throw "Workflow phase is missing: $scriptPath"
	}
	& $scriptPath @Parameters
}

if ($Diagnostics) {
	Invoke-WorkflowPhase -ScriptName 'Start-Update.ps1' -Parameters @{ Diagnostics = $true }
	return
}
if ($WhatIf) {
	Invoke-WorkflowPhase -ScriptName 'Publish-Update.ps1' -Parameters @{ WhatIf = $true }
	return
}

$repositoryRoot = Get-WorkflowRepositoryRoot
Push-Location $repositoryRoot
try {
	$exitRequested = $false
	while (-not $exitRequested) {
		$session = Read-WorkflowSession -RepositoryRoot $repositoryRoot
		Write-Host ''
		Write-Host 'Website content workflow' -ForegroundColor Cyan
		if ($null -eq $session) {
			Write-Host 'No active batch.'
		} else {
			$itemCount = @((Get-WorkflowProperty -InputObject $session -Name 'Items' -Default @())).Count
			Write-Host "Active batch: $($session.SessionId) | $itemCount item(s) | status: $($session.Status)"
		}
		Write-Host ''
		Write-Host '  1. Start or extend a content batch'
		Write-Host '  2. Add an image, project cover, STL model, or resume PDF'
		Write-Host '  3. Preview, validate, and review the batch'
		Write-Host '  4. Publish the reviewed batch live'
		Write-Host '  5. Preview the publication plan (WhatIf)'
		Write-Host '  6. Resume deployment monitoring'
		Write-Host '  7. Run read-only diagnostics'
		Write-Host '  0. Exit'
		$answer = Read-Host 'Choose an action'
		switch ($answer) {
			'1' { Invoke-WorkflowPhase -ScriptName 'Start-Update.ps1'; $exitRequested = $true }
			'2' { Invoke-WorkflowPhase -ScriptName 'Add-Asset.ps1'; $exitRequested = $true }
			'3' { Invoke-WorkflowPhase -ScriptName 'Review-Update.ps1'; $exitRequested = $true }
			'4' { Invoke-WorkflowPhase -ScriptName 'Publish-Update.ps1'; $exitRequested = $true }
			'5' { Invoke-WorkflowPhase -ScriptName 'Publish-Update.ps1' -Parameters @{ WhatIf = $true }; $exitRequested = $true }
			'6' {
				$sha = if ($null -ne $session) { [string]$session.CommitSha } else { '' }
				if (-not $sha) { $sha = (Read-Host 'Full 40-character commit SHA').Trim() }
				Invoke-WorkflowPhase -ScriptName 'Watch-Deployment.ps1' -Parameters @{ CommitSha = $sha }
				$exitRequested = $true
			}
			'7' { Invoke-WorkflowPhase -ScriptName 'Start-Update.ps1' -Parameters @{ Diagnostics = $true }; $exitRequested = $true }
			'0' { $exitRequested = $true }
			default { Write-Warning 'Choose a listed number.' }
		}
	}
} catch {
	Write-Host ''
	Write-Host 'The website content workflow could not continue.' -ForegroundColor Red
	Write-Host $_.Exception.Message -ForegroundColor Yellow
	Write-Host ''
	Write-Host 'Nothing was committed or pushed. Correct the issue above, then run the launcher again.'
	exit 1
} finally {
	Pop-Location
}
