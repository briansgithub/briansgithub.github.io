#requires -Version 5.1

<#
.SYNOPSIS
	Publishes every pending change in the working tree to bellsworth.dev in one pass.

.DESCRIPTION
	The guided workflow in Start-ContentWorkflow.ps1 tracks a recorded batch and
	refuses to publish anything outside it. This script takes the opposite view:
	whatever Git reports as changed is the unit of work. Ignored paths cannot
	reach it, because Get-WorkflowChangedPaths honours .gitignore.

	Safety is unchanged from the guided workflow: main only, canonical origin,
	hooks enabled, the full verification gate, a visible staged diff, an exact
	typed PUBLISH confirmation, and a plain non-forced push.

.PARAMETER WhatIf
	Reports what would be published and stops before formatting, staging,
	committing, or pushing. Still runs the verification gate.

.PARAMETER TerminalDiff
	Prints the staged diff in the console instead of opening it in VS Code.
	The console is also used automatically when VS Code is not on PATH.
#>

[CmdletBinding()]
param(
	[switch]$WhatIf,
	[switch]$TerminalDiff
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'Workflow.Common.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
	throw "The shared authoring module was not found: $modulePath"
}
Import-Module $modulePath -Force

# Extensions Prettier owns in this repository. Anything else is left untouched.
$prettierExtensions = @(
	'.astro',
	'.css',
	'.html',
	'.js',
	'.json',
	'.jsonc',
	'.md',
	'.mdx',
	'.mjs',
	'.ts',
	'.yaml',
	'.yml'
)

function Write-Step {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	Write-Host ''
	Write-Host $Message -ForegroundColor Cyan
}

function Show-PathList {
	[CmdletBinding()]
	param(
		[string[]]$Paths = @()
	)

	foreach ($path in $Paths) {
		Write-Host "  $path"
	}
}

function Repair-DuplicateEntryPoint {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$RepositoryRoot
	)

	# CLAUDE.md is a hard link to AGENTS.md. Prettier rewrites a file by replacing it
	# rather than editing in place, which breaks the link and leaves two entry points
	# holding contradictory guidance. AGENTS.md is the documented source of truth.
	$primary = Join-Path $RepositoryRoot 'AGENTS.md'
	$mirror = Join-Path $RepositoryRoot 'CLAUDE.md'
	if (-not (Test-Path -LiteralPath $primary -PathType Leaf)) {
		return
	}
	if (-not (Test-Path -LiteralPath $mirror -PathType Leaf)) {
		return
	}
	if ((Get-FileHash -LiteralPath $primary).Hash -eq (Get-FileHash -LiteralPath $mirror).Hash) {
		return
	}

	Write-Host 'CLAUDE.md drifted from AGENTS.md. Restoring the hard link.' -ForegroundColor Yellow
	Remove-Item -LiteralPath $mirror -Force
	New-Item -ItemType HardLink -Path $mirror -Target $primary | Out-Null
}

function Show-StagedDiff {
	[CmdletBinding()]
	param(
		[switch]$ForceTerminal
	)

	if (-not $ForceTerminal -and -not (Test-WorkflowCommand -Name 'code')) {
		Write-Host 'VS Code is not on PATH, so the diff is shown here instead.' -ForegroundColor Yellow
		$ForceTerminal = $true
	}
	if ($ForceTerminal) {
		Write-Host ''
		Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('--no-pager', 'diff', '--cached') | Out-Null
		return
	}

	Write-Host ''
	Write-Host 'Opening each change in VS Code. Close a diff tab to move on to the next file.'
	Write-Host 'This window waits until the last tab is closed.'

	# Let git build the before and after files. It gets the bytes exactly right for
	# added, deleted, renamed, and binary paths, and --wait keeps them on disk until
	# the tab closes.
	#
	# The settings travel as GIT_CONFIG_* environment variables rather than `git -c`
	# arguments. Windows PowerShell 5.1 does not escape the embedded double quotes
	# around $LOCAL and $REMOTE when it hands an argument to a native executable, so
	# the -c form arrives at git split across several arguments. Environment values
	# are passed verbatim. The keys are saved and restored so a caller that already
	# uses this mechanism is left untouched.
	#
	# git passes /dev/null for the missing side of an added or deleted file, and VS Code
	# cannot open that path on Windows. Swap in a real empty file, converted to a Windows
	# path because VS Code is a native application and mktemp reports an MSYS path.
	$editorCommand = @(
		'L="$LOCAL"; R="$REMOTE"; LT=; RT='
		'[ "$L" = /dev/null ] && { LT=$(mktemp --suffix=.empty); L=$(cygpath -w "$LT" 2>/dev/null || echo "$LT"); }'
		'[ "$R" = /dev/null ] && { RT=$(mktemp --suffix=.empty); R=$(cygpath -w "$RT" 2>/dev/null || echo "$RT"); }'
		'code --wait --reuse-window --diff "$L" "$R"'
		'status=$?'
		'[ -n "$LT" ] && rm -f "$LT"'
		'[ -n "$RT" ] && rm -f "$RT"'
		'exit $status'
	) -join '; '

	$configuration = [ordered]@{
		GIT_CONFIG_COUNT = '2'
		GIT_CONFIG_KEY_0 = 'difftool.vscode.cmd'
		GIT_CONFIG_VALUE_0 = $editorCommand
		GIT_CONFIG_KEY_1 = 'diff.tool'
		GIT_CONFIG_VALUE_1 = 'vscode'
	}
	$saved = @{}
	foreach ($name in $configuration.Keys) {
		$saved[$name] = [Environment]::GetEnvironmentVariable($name)
	}
	try {
		foreach ($name in $configuration.Keys) {
			[Environment]::SetEnvironmentVariable($name, $configuration[$name])
		}
		Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'difftool', '--staged', '--no-prompt'
		) | Out-Null
	} finally {
		foreach ($name in $saved.Keys) {
			[Environment]::SetEnvironmentVariable($name, $saved[$name])
		}
	}
}

$repositoryRoot = Get-WorkflowRepositoryRoot
Push-Location $repositoryRoot
try {
	Write-Host ''
	Write-Host 'Publish website changes' -ForegroundColor Cyan
	if ($WhatIf) {
		Write-Host 'WHAT-IF: nothing will be formatted, staged, committed, or pushed.' -ForegroundColor Yellow
	}

	$branch = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'branch', '--show-current'
		) -CaptureOutput).Text
	if ($branch -ne 'main') {
		throw "Publication is allowed only from main. The current branch is '$branch'."
	}
	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null

	Write-Step 'Collecting every pending change...'
	$changedPaths = @(Get-WorkflowChangedPaths -RepositoryRoot $repositoryRoot)
	if ($changedPaths.Count -eq 0) {
		Write-Host ''
		Write-Host 'Nothing to publish. The working tree is already clean.' -ForegroundColor Green
		return
	}
	Show-PathList -Paths $changedPaths

	# Obsidian rewrites frontmatter quoting and drops trailing newlines, which fails
	# the format check every time. Fix it here so it never reaches a human.
	$formatTargets = @($changedPaths | Where-Object {
			$prettierExtensions -contains [IO.Path]::GetExtension($_) -and
			(Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf)
		})
	if ($formatTargets.Count -gt 0) {
		if ($WhatIf) {
			$different = Invoke-WorkflowNative -FilePath 'npx.cmd' -ArgumentList (
				@('prettier', '--list-different', '--') + $formatTargets
			) -CaptureOutput -AllowFailure
			$wouldFormat = @($different.Lines |
					Where-Object { $_ -and $_ -notmatch '^Checking formatting' } |
					ForEach-Object { $_.Replace('\', '/') })
			if ($wouldFormat.Count -gt 0) {
				Write-Step 'WHAT-IF: Prettier would rewrite these files before verifying:'
				Show-PathList -Paths $wouldFormat
				Write-Host ''
				Write-Host 'The verification gate below runs against the unformatted files, so any' -ForegroundColor Yellow
				Write-Host 'formatting failure it reports is one a real run would have fixed first.' -ForegroundColor Yellow
			} else {
				Write-Step 'WHAT-IF: every changed file is already correctly formatted.'
			}
		} else {
			Write-Step 'Formatting changed files with Prettier...'
			Invoke-WorkflowNative -FilePath 'npx.cmd' -ArgumentList (
				@('prettier', '--write', '--') + $formatTargets
			) | Out-Null
			Repair-DuplicateEntryPoint -RepositoryRoot $repositoryRoot

			# Formatting can create or resolve changes, so recollect before staging.
			$changedPaths = @(Get-WorkflowChangedPaths -RepositoryRoot $repositoryRoot)
			if ($changedPaths.Count -eq 0) {
				Write-Host ''
				Write-Host 'Nothing to publish. The working tree is already clean.' -ForegroundColor Green
				return
			}
		}
	}

	Write-Step 'Checking origin/main...'
	Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('fetch', '--prune', 'origin', 'main') | Out-Null
	$counts = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-list', '--left-right', '--count', 'origin/main...HEAD'
		) -CaptureOutput).Text -split '\s+'
	if ($counts.Count -lt 2) {
		throw 'Git did not return the expected ahead/behind counts for origin/main.'
	}
	$behind = [int]$counts[0]
	$ahead = [int]$counts[1]
	if ($behind -gt 0) {
		throw "Local main is $behind commit(s) behind origin/main. Publication stopped so that nothing is merged or rebased automatically. Reconcile the remote changes, then run this launcher again."
	}
	$remoteBeforeVerify = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-parse', 'refs/remotes/origin/main'
		) -CaptureOutput).Text
	Write-Host "Local main is $ahead commit(s) ahead of origin/main before this commit."

	Write-Step 'Running the full verification gate (npm run verify)...'
	Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('run', 'verify') | Out-Null

	if ($WhatIf) {
		Write-Step 'WHAT-IF publication plan:'
		Write-Host '  1. Format the changed files listed above.'
		Write-Host '  2. Stage exactly those paths.'
		Write-Host '  3. Open each staged change in VS Code, then request a commit message.'
		Write-Host '  4. Require the exact confirmation PUBLISH.'
		Write-Host '  5. Commit, recheck origin/main, and push main without force.'
		Write-Host '  6. Watch the GitHub Actions run and test the live routes.'
		return
	}

	Write-Step 'Staging the changed files...'
	Invoke-WorkflowNative -FilePath 'git' -ArgumentList (@('add', '--') + $changedPaths) | Out-Null
	$stagedPaths = @(
		(Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'diff', '--cached', '--name-only'
		) -CaptureOutput).Lines |
			Where-Object { $_ } |
			ForEach-Object { $_.Replace('\', '/') } |
			Sort-Object -Unique
	)
	if ($stagedPaths.Count -eq 0) {
		Write-Host ''
		Write-Host 'Nothing was staged. The changes may already have been committed.' -ForegroundColor Green
		return
	}

	Write-Step 'These files will be published:'
	Show-PathList -Paths $stagedPaths
	Show-StagedDiff -ForceTerminal:$TerminalDiff

	$defaultCommitMessage = 'Update website content'
	Write-Host ''
	$commitMessage = Read-Host "Commit message [$defaultCommitMessage]"
	if (-not $commitMessage -or -not $commitMessage.Trim()) {
		$commitMessage = $defaultCommitMessage
	} else {
		$commitMessage = $commitMessage.Trim()
	}
	if ($commitMessage -match "[`r`n]") {
		throw 'Use a single-line commit message.'
	}

	Write-Host ''
	Write-Host 'This is the final publishing boundary.' -ForegroundColor Yellow
	Write-Host 'The next step commits these files and pushes main to GitHub.'
	$confirmation = Read-Host 'Type PUBLISH exactly to continue'
	if ($confirmation -cne 'PUBLISH') {
		Write-Warning 'Publication cancelled. The files remain staged, and nothing was committed or pushed.'
		return
	}

	Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('commit', '-m', $commitMessage) | Out-Null
	$commitSha = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-parse', 'HEAD'
		) -CaptureOutput).Text
	Write-Host "Created commit $commitSha." -ForegroundColor Green

	Write-Step 'Rechecking origin/main immediately before the push...'
	Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('fetch', '--prune', 'origin', 'main') | Out-Null
	$remoteBeforePush = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-parse', 'refs/remotes/origin/main'
		) -CaptureOutput).Text
	if ($remoteBeforePush -ne $remoteBeforeVerify) {
		throw "origin/main changed before the push. The local commit $commitSha is safe but was not pushed. Reconcile the remote changes, then run this launcher again."
	}

	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
	Write-Step 'Pushing main...'
	Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('push', 'origin', 'main') | Out-Null
	Write-Host 'Pushed.' -ForegroundColor Green

	# A guided-workflow batch covering these files is now finished. Leaving it behind
	# would make the guided workflow try to resume work that is already live.
	$sessionPath = Get-WorkflowSessionPath -RepositoryRoot $repositoryRoot
	if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
		$session = Read-WorkflowSession -RepositoryRoot $repositoryRoot
		$expectedPaths = @(Get-WorkflowProperty -InputObject $session -Name 'ExpectedPaths' -Default @())
		$outstanding = @($expectedPaths | Where-Object { $stagedPaths -notcontains $_ })
		if ($expectedPaths.Count -gt 0 -and $outstanding.Count -eq 0) {
			Remove-Item -LiteralPath $sessionPath -Force
			Write-Host 'Cleared the guided workflow batch; every file it tracked is now published.' -ForegroundColor Green
		}
	}

	$watchScript = Join-Path $PSScriptRoot 'Watch-Deployment.ps1'
	if (Test-Path -LiteralPath $watchScript -PathType Leaf) {
		& $watchScript -CommitSha $commitSha
	} else {
		Write-Warning "Deployment monitoring was skipped because $watchScript is missing."
	}
} catch {
	Write-Host ''
	Write-Host 'Publishing could not continue.' -ForegroundColor Red
	Write-Host $_.Exception.Message -ForegroundColor Yellow
	Write-Host ''
	Write-Host 'Read the message above, correct the issue, then run the launcher again.'
	exit 1
} finally {
	Pop-Location
}
