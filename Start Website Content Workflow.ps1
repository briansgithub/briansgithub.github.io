#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$Diagnostics,
	[switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'scripts\authoring\Start-ContentWorkflow.ps1'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
	throw "The website content workflow launcher is missing: $launcher"
}

& $launcher @PSBoundParameters
$workflowSucceeded = $?
$workflowExitCode = $LASTEXITCODE
if (-not $workflowSucceeded) {
	if ($workflowExitCode -is [int] -and $workflowExitCode -ne 0) {
		exit $workflowExitCode
	}
	exit 1
}
