#requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'scripts\authoring\launch-authoring-tools.mjs'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
	throw "The authoring tools launcher is missing: $launcher"
}

& node.exe $launcher @args
$workflowSucceeded = $?
$workflowExitCode = $LASTEXITCODE
if (-not $workflowSucceeded) {
	if ($workflowExitCode -is [int] -and $workflowExitCode -ne 0) {
		exit $workflowExitCode
	}
	exit 1
}
