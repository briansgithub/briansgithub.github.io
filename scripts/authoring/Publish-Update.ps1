#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'Workflow.Common.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
	throw "The shared authoring module was not found: $modulePath"
}
Import-Module $modulePath -Force

function Invoke-CheckedNative {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath,

		[Parameter(Mandatory = $true)]
		[string[]]$Arguments,

		[switch]$CaptureOutput,

		[switch]$AllowFailure
	)

	$oldErrorActionPreference = $ErrorActionPreference
	try {
		$ErrorActionPreference = 'Continue'
		if ($CaptureOutput) {
			$commandOutput = @(& $FilePath @Arguments 2>&1)
			$exitCode = $LASTEXITCODE
			$outputLines = @($commandOutput | ForEach-Object { $_.ToString() })
		} else {
			& $FilePath @Arguments 2>&1 | ForEach-Object { Write-Host $_.ToString() }
			$exitCode = $LASTEXITCODE
			$outputLines = @()
		}
		$result = [pscustomobject]@{
			ExitCode = $exitCode
			Lines = $outputLines
			Text = ($outputLines -join [Environment]::NewLine).Trim()
		}
	} finally {
		$ErrorActionPreference = $oldErrorActionPreference
	}

	if ($exitCode -ne 0 -and -not $AllowFailure) {
		$displayCommand = "$FilePath $($Arguments -join ' ')"
		$detail = ($outputLines -join [Environment]::NewLine).Trim()
		if ($detail) {
			throw "Command failed with exit code ${exitCode}: $displayCommand`n$detail"
		}
		throw "Command failed with exit code ${exitCode}: $displayCommand"
	}

	return $result
}

function Get-WorkflowValue {
	param(
		[AllowNull()]
		[object]$InputObject,

		[Parameter(Mandatory = $true)]
		[string[]]$Names
	)

	if ($null -eq $InputObject) {
		return $null
	}

	foreach ($name in $Names) {
		$property = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $name }) |
			Select-Object -First 1
		if ($null -ne $property) {
			return $property.Value
		}
	}

	return $null
}

function Set-WorkflowValue {
	param(
		[Parameter(Mandatory = $true)]
		[object]$InputObject,

		[Parameter(Mandatory = $true)]
		[string]$Name,

		[AllowNull()]
		[object]$Value
	)

	$property = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Name }) |
		Select-Object -First 1
	if ($null -ne $property) {
		$property.Value = $Value
		return
	}

	$InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

function Get-NestedWorkflowValue {
	param(
		[Parameter(Mandatory = $true)]
		[object]$InputObject,

		[Parameter(Mandatory = $true)]
		[string[][]]$Paths
	)

	foreach ($path in $Paths) {
		$current = $InputObject
		$found = $true
		foreach ($segment in $path) {
			$current = Get-WorkflowValue -InputObject $current -Names @($segment)
			if ($null -eq $current) {
				$found = $false
				break
			}
		}
		if ($found) {
			return $current
		}
	}

	return $null
}

function ConvertTo-WorkflowPath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[string]$RepositoryRoot
	)

	$candidate = $Path.Trim()
	if (-not $candidate) {
		throw 'The workflow session contains an empty expected path.'
	}

	if ([System.IO.Path]::IsPathRooted($candidate)) {
		$candidate = Get-WorkflowRelativePath -Path $candidate -RepositoryRoot $RepositoryRoot
	}

	$candidate = $candidate.Replace('\', '/').TrimStart('/')
	if ($candidate -eq '..' -or $candidate.StartsWith('../') -or $candidate.Contains('/../')) {
		throw "The workflow session contains a path outside the repository: $Path"
	}
	if ($candidate.StartsWith('.authoring-workflow/', [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Ignored workflow state cannot be published: $candidate"
	}

	return $candidate
}

function Get-ExpectedWorkflowPaths {
	param(
		[Parameter(Mandatory = $true)]
		[object]$Session,

		[Parameter(Mandatory = $true)]
		[string]$RepositoryRoot
	)

	$recordedPaths = Get-WorkflowValue -InputObject $Session -Names @(
		'ExpectedPaths',
		'ExpectedGitPaths',
		'TrackedPaths'
	)
	if ($null -eq $recordedPaths) {
		throw 'The active authoring session does not record any expected Git paths.'
	}

	$paths = @(
		$recordedPaths |
			ForEach-Object { ConvertTo-WorkflowPath -Path ([string]$_) -RepositoryRoot $RepositoryRoot } |
			Sort-Object -Unique
	)
	if ($paths.Count -eq 0) {
		throw 'The active authoring session has no expected Git paths to publish.'
	}

	return $paths
}

function Get-SessionRoutes {
	param(
		[Parameter(Mandatory = $true)]
		[object]$Session
	)

	$items = @(Get-WorkflowValue -InputObject $Session -Names @('Items', 'BatchItems'))
	$routes = New-Object System.Collections.Generic.List[string]
	foreach ($item in $items) {
		$route = Get-WorkflowValue -InputObject $item -Names @('Route', 'PublicRoute', 'UrlPath')
		if ($null -eq $route) {
			continue
		}

		$routeText = ([string]$route).Trim()
		if (-not $routeText) {
			continue
		}
		if ($routeText -match '^https?://') {
			$uri = [Uri]$routeText
			if ($uri.Host -ne 'bellsworth.dev') {
				throw "The workflow session contains an unexpected live host: $($uri.Host)"
			}
			$routeText = $uri.PathAndQuery
		}
		if (-not $routeText.StartsWith('/')) {
			$routeText = "/$routeText"
		}
		$routes.Add($routeText)
	}

	return @($routes | Sort-Object -Unique)
}

function Show-PublishSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Paths,

		[Parameter(Mandatory = $true)]
		[string[]]$Routes,

		[switch]$Staged
	)

	Write-Host ''
	Write-Host 'Files in this publication:' -ForegroundColor Cyan
	$Paths | ForEach-Object { Write-Host "  $_" }

	$binaryExtensions = @(
		'.avif', '.gif', '.ico', '.jpeg', '.jpg', '.pdf', '.png', '.stl', '.webp', '.woff', '.woff2'
	)
	$binaryPaths = @($Paths | Where-Object { $binaryExtensions -contains [IO.Path]::GetExtension($_).ToLowerInvariant() })
	if ($binaryPaths.Count -gt 0) {
		Write-Host ''
		Write-Host 'Binary files:' -ForegroundColor Cyan
		foreach ($path in $binaryPaths) {
			$fullPath = Join-Path (Get-Location).Path $path
			if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
				$size = (Get-Item -LiteralPath $fullPath).Length
				Write-Host ('  {0} ({1:N0} bytes)' -f $path, $size)
			} else {
				Write-Host "  $path (deleted)"
			}
		}
	}

	Write-Host ''
	Write-Host 'Live pages affected:' -ForegroundColor Cyan
	if ($Routes.Count -eq 0) {
		Write-Host '  https://bellsworth.dev/'
	} else {
		$Routes | ForEach-Object { Write-Host "  https://bellsworth.dev$($_)" }
	}

	Write-Host ''
	Write-Host 'Commits already waiting to be pushed:' -ForegroundColor Cyan
	$logResult = Invoke-CheckedNative -FilePath 'git' -Arguments @(
		'log', '--oneline', '--decorate', 'origin/main..HEAD'
	) -CaptureOutput
	if ($logResult.Lines.Count -eq 0) {
		Write-Host '  (none)'
	} else {
		$logResult.Lines | ForEach-Object { Write-Host "  $_" }
	}

	if ($Staged) {
		Write-Host ''
		Write-Host 'Staged summary:' -ForegroundColor Cyan
		Invoke-CheckedNative -FilePath 'git' -Arguments @('diff', '--cached', '--stat') | Out-Null
		Write-Host ''
		Write-Host 'Staged diff:' -ForegroundColor Cyan
		Invoke-CheckedNative -FilePath 'git' -Arguments @('diff', '--cached', '--') | Out-Null
	}
}

$repositoryRoot = Get-WorkflowRepositoryRoot
Push-Location $repositoryRoot
try {
	$session = Read-WorkflowSession -RepositoryRoot $repositoryRoot
	if ($null -eq $session) {
		throw 'There is no active authoring session. Start one with npm run content:workflow.'
	}

	$currentBranch = (Invoke-CheckedNative -FilePath 'git' -Arguments @('branch', '--show-current') -CaptureOutput).Text
	if ($currentBranch -ne 'main') {
		throw "Publication is allowed only from main. The current branch is '$currentBranch'."
	}
	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	$sessionStatus = [string](Get-WorkflowValue -InputObject $session -Names @('Status'))
	$existingCommitSha = [string](Get-WorkflowValue -InputObject $session -Names @(
		'CommitSha',
		'PublishedCommitSha'
	))
	if ($WhatIf -and $sessionStatus -in @(
			'commit-pending',
			'committed',
			'pushed',
			'deploying',
			'published'
		)) {
		throw "WHAT-IF will not resume a batch in '$sessionStatus' state because resuming could commit, push, monitor, or archive it. Use the normal Publish or deployment-monitoring action."
	}
	if ($sessionStatus -in @('pushed', 'deploying', 'published')) {
		if ($existingCommitSha -notmatch '^[0-9a-fA-F]{40}$') {
			throw "The session status is '$sessionStatus' but it does not record a valid commit SHA."
		}
		Write-Host "Resuming deployment monitoring for $existingCommitSha..." -ForegroundColor Cyan
		& (Join-Path $PSScriptRoot 'Watch-Deployment.ps1') -CommitSha $existingCommitSha
		return
	}
	if ($sessionStatus -eq 'commit-pending') {
		$preCommitHead = [string](Get-WorkflowValue -InputObject $session -Names @('PreCommitHead'))
		$pendingTree = [string](Get-WorkflowValue -InputObject $session -Names @('PendingTree'))
		$pendingCommitMessage = [string](Get-WorkflowValue -InputObject $session -Names @(
			'PendingCommitMessage'
		))
		$pendingStagedPaths = @(
			Get-WorkflowValue -InputObject $session -Names @('PendingStagedPaths') |
				ForEach-Object { ([string]$_).Replace('\', '/') } |
				Where-Object { $_ } |
				Sort-Object -Unique
		)
		if ($preCommitHead -notmatch '^[0-9a-fA-F]{40}$' -or
			$pendingTree -notmatch '^[0-9a-fA-F]{40}$' -or
			-not $pendingCommitMessage -or $pendingStagedPaths.Count -eq 0) {
			throw 'The interrupted commit record is incomplete. Inspect the Git state and session manually.'
		}

		$currentHead = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'rev-parse', 'HEAD'
		) -CaptureOutput).Text
		if ($currentHead -eq $preCommitHead) {
			$currentStagedPaths = @(
				(Invoke-CheckedNative -FilePath 'git' -Arguments @(
					'diff', '--cached', '--name-only'
				) -CaptureOutput).Lines |
					Where-Object { $_ } |
					ForEach-Object { $_.Replace('\', '/') } |
					Sort-Object -Unique
			)
			if (($currentStagedPaths -join "`n") -cne ($pendingStagedPaths -join "`n")) {
				throw 'The staged paths changed after PUBLISH was confirmed. Inspect them manually before resuming.'
			}
			$unstagedPaths = @(
				@(
					(Invoke-CheckedNative -FilePath 'git' -Arguments @(
						'diff', '--name-only', '--'
					) -CaptureOutput).Lines
					(Invoke-CheckedNative -FilePath 'git' -Arguments @(
						'ls-files', '--others', '--exclude-standard'
					) -CaptureOutput).Lines
				) | Where-Object { $_ } | Sort-Object -Unique
			)
			if ($unstagedPaths.Count -gt 0) {
				throw "Files changed after PUBLISH was confirmed. The pending commit was not resumed:`n$($unstagedPaths -join "`n")"
			}
			$currentTree = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'write-tree'
			) -CaptureOutput).Text
			if ($currentTree -ne $pendingTree) {
				throw 'The staged content changed after PUBLISH was confirmed. Inspect the index manually.'
			}
			Write-Host 'Resuming the previously confirmed commit...' -ForegroundColor Cyan
			Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
			Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
			Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'commit', '-m', $pendingCommitMessage
			) | Out-Null
			$currentHead = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'rev-parse', 'HEAD'
			) -CaptureOutput).Text
		} else {
			$commitParent = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'rev-parse', "${currentHead}^"
			) -CaptureOutput -AllowFailure).Text
			$commitTree = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'rev-parse', "${currentHead}^{tree}"
			) -CaptureOutput -AllowFailure).Text
			if ($commitParent -ne $preCommitHead -or $commitTree -ne $pendingTree) {
				throw "HEAD changed after PUBLISH was confirmed, but it is not the exact pending commit. Expected parent $preCommitHead and tree $pendingTree; inspect Git manually."
			}
			Write-Host "Recovered the completed commit after an interrupted session write: $currentHead" -ForegroundColor Green
		}
		Set-WorkflowValue -InputObject $session -Name 'CommitSha' -Value $currentHead
		Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'committed'
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
		$sessionStatus = 'committed'
		$existingCommitSha = $currentHead
	}
	if ($sessionStatus -eq 'committed') {
		if ($existingCommitSha -notmatch '^[0-9a-fA-F]{40}$') {
			throw 'The committed session does not record a valid commit SHA.'
		}
		$headCommit = (Invoke-CheckedNative -FilePath 'git' -Arguments @('rev-parse', 'HEAD') `
			-CaptureOutput).Text
		if ($headCommit -ne $existingCommitSha) {
			throw "The session commit is $existingCommitSha, but HEAD is $headCommit. Resolve this manually before resuming."
		}
		$expectedResumeRemote = [string](Get-NestedWorkflowValue -InputObject $session -Paths @(
			@('RemoteCommit'),
			@('StartingRemoteCommit'),
			@('Baseline', 'RemoteCommit')
		))
		Write-Host 'Resuming a publication that was already confirmed and committed.' -ForegroundColor Cyan
		Invoke-CheckedNative -FilePath 'git' -Arguments @('fetch', '--prune', 'origin', 'main') |
			Out-Null
		$currentResumeRemote = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'rev-parse', 'refs/remotes/origin/main'
		) -CaptureOutput).Text
		$alreadyPushed = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'merge-base', '--is-ancestor', $existingCommitSha, 'origin/main'
		) -CaptureOutput -AllowFailure).ExitCode -eq 0
		if (-not $alreadyPushed -and $currentResumeRemote -ne $expectedResumeRemote) {
			throw "origin/main changed after the content commit was created. The safe local commit $existingCommitSha was not pushed; reconcile the remote manually."
		}
		if (-not $alreadyPushed) {
			Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
			Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
			$upstream = Invoke-CheckedNative -FilePath 'git' -Arguments @(
				'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'
			) -CaptureOutput -AllowFailure
			if ($upstream.ExitCode -ne 0 -or $upstream.Text -ne 'origin/main') {
				Invoke-CheckedNative -FilePath 'git' -Arguments @('push', '-u', 'origin', 'main') |
					Out-Null
			} else {
				Invoke-CheckedNative -FilePath 'git' -Arguments @('push', 'origin', 'main') | Out-Null
			}
		}
		Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'pushed'
		Set-WorkflowValue -InputObject $session -Name 'PushedAtUtc' -Value ([DateTime]::UtcNow.ToString('o'))
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
		& (Join-Path $PSScriptRoot 'Watch-Deployment.ps1') -CommitSha $existingCommitSha
		return
	}
	if (-not $WhatIf -and $sessionStatus -ne 'ready-to-publish') {
		throw "This batch is '$sessionStatus', not ready to publish. Run the Preview, validate, and review phase first."
	}

	$expectedPaths = @(Get-ExpectedWorkflowPaths -Session $session -RepositoryRoot $repositoryRoot)
	$changedPaths = @(Get-WorkflowChangedPaths -RepositoryRoot $repositoryRoot | ForEach-Object {
			ConvertTo-WorkflowPath -Path ([string]$_) -RepositoryRoot $repositoryRoot
		} | Sort-Object -Unique)
	if ($changedPaths.Count -eq 0) {
		throw 'No website changes are present for this authoring session.'
	}

	Assert-NoUnexpectedWorkflowChanges -RepositoryRoot $repositoryRoot -Session $session | Out-Null
	$publishPaths = @($changedPaths | Where-Object { $expectedPaths -contains $_ })
	if ($publishPaths.Count -eq 0) {
		throw 'None of the changed files are recorded in the active authoring session.'
	}
	$routes = @(Get-SessionRoutes -Session $session)

	$expectedRemoteCommit = Get-NestedWorkflowValue -InputObject $session -Paths @(
		@('RemoteCommit'),
		@('StartingRemoteCommit'),
		@('Baseline', 'RemoteCommit')
	)
	if (-not $expectedRemoteCommit) {
		throw 'The active session does not record the origin/main commit from when editing began.'
	}
	$expectedRemoteCommit = ([string]$expectedRemoteCommit).Trim()

	if ($WhatIf) {
		Write-Host 'WHAT-IF: no source files, Git references, session state, commits, or remotes will be changed. Verification may refresh ignored build caches.' -ForegroundColor Yellow
		Write-Host 'Reading origin/main without updating the local remote-tracking reference...'
		$remoteResult = Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'ls-remote', '--exit-code', 'origin', 'refs/heads/main'
		) -CaptureOutput
		$currentRemoteCommit = ($remoteResult.Text -split '\s+')[0]
	} else {
		Write-Host 'Checking that origin/main has not changed while you were editing...'
		Invoke-CheckedNative -FilePath 'git' -Arguments @('fetch', '--prune', 'origin', 'main') | Out-Null
		$currentRemoteCommit = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'rev-parse', 'refs/remotes/origin/main'
		) -CaptureOutput).Text
	}

	if ($currentRemoteCommit -ne $expectedRemoteCommit) {
		throw "origin/main changed after this session began. Expected $expectedRemoteCommit but found $currentRemoteCommit. Start a new session after reconciling the remote changes."
	}

	$counts = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
		'rev-list', '--left-right', '--count', 'origin/main...HEAD'
	) -CaptureOutput).Text -split '\s+'
	if ($counts.Count -lt 2) {
		throw 'Git did not return the expected ahead/behind counts for origin/main.'
	}
	$behind = [int]$counts[0]
	$ahead = [int]$counts[1]
	if ($behind -gt 0) {
		throw "Local main is $behind commit(s) behind origin/main. Publication has stopped to avoid an automatic merge or rebase."
	}
	Write-Host "Local main is $ahead commit(s) ahead of origin/main before this content commit."

	Write-Host ''
	Write-Host 'Running the complete repository verification gate...'
	Invoke-CheckedNative -FilePath 'npm.cmd' -Arguments @('run', 'verify') | Out-Null

	Show-PublishSummary -Paths $publishPaths -Routes $routes

	if ($WhatIf) {
		Write-Host ''
		Write-Host 'WHAT-IF publication plan:' -ForegroundColor Yellow
		Write-Host '  1. Stage only the files listed above.'
		Write-Host '  2. Show the staged diff and request an editable commit message.'
		Write-Host '  3. Require the exact confirmation PUBLISH.'
		Write-Host '  4. Commit, recheck origin/main, and push main without force.'
		Write-Host '  5. Watch the exact GitHub Actions run and test the live routes.'
		return
	}

	Set-WorkflowValue -InputObject $session -Name 'Verification' -Value ([pscustomobject]@{
		Status = 'passed'
		VerifiedAtUtc = [DateTime]::UtcNow.ToString('o')
		HeadCommit = (Invoke-CheckedNative -FilePath 'git' -Arguments @('rev-parse', 'HEAD') -CaptureOutput).Text
	})
	Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

	Write-Host ''
	Write-Host 'Staging only the paths recorded by this authoring session...'
	Invoke-CheckedNative -FilePath 'git' -Arguments (@('add', '--') + $publishPaths) | Out-Null

	$stagedPaths = @(
		(Invoke-CheckedNative -FilePath 'git' -Arguments @(
			'diff', '--cached', '--name-only'
		) -CaptureOutput).Lines |
			Where-Object { $_ } |
			ForEach-Object { $_.Replace('\', '/') } |
			Sort-Object -Unique
	)
	$unexpectedStaged = @($stagedPaths | Where-Object { $expectedPaths -notcontains $_ })
	if ($unexpectedStaged.Count -gt 0) {
		throw "Unexpected files are staged and publication has stopped:`n$($unexpectedStaged -join "`n")"
	}
	if ($stagedPaths.Count -eq 0) {
		throw 'Nothing was staged. The working changes may already have been committed.'
	}

	Show-PublishSummary -Paths $stagedPaths -Routes $routes -Staged

	$defaultCommitMessage = Get-WorkflowValue -InputObject $session -Names @(
		'SuggestedCommitMessage',
		'CommitMessage'
	)
	if (-not $defaultCommitMessage) {
		$defaultCommitMessage = 'Update website content'
	}
	$commitMessage = Read-Host "Commit message [$defaultCommitMessage]"
	if (-not $commitMessage.Trim()) {
		$commitMessage = [string]$defaultCommitMessage
	}
	if ($commitMessage -match "[`r`n]") {
		throw 'Use a single-line commit message.'
	}

	Write-Host ''
	Write-Host 'This is the final publishing boundary.' -ForegroundColor Yellow
	Write-Host 'The next step will commit these files and push every outgoing main commit to GitHub.'
	$confirmation = Read-Host 'Type PUBLISH exactly to continue'
	if ($confirmation -cne 'PUBLISH') {
		Write-Warning 'Publication cancelled. The reviewed files remain staged so this session can be resumed.'
		return
	}

	$preCommitHead = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
		'rev-parse', 'HEAD'
	) -CaptureOutput).Text
	$pendingTree = (Invoke-CheckedNative -FilePath 'git' -Arguments @('write-tree') -CaptureOutput).Text
	Set-WorkflowValue -InputObject $session -Name 'PreCommitHead' -Value $preCommitHead
	Set-WorkflowValue -InputObject $session -Name 'PendingTree' -Value $pendingTree
	Set-WorkflowValue -InputObject $session -Name 'PendingStagedPaths' -Value $stagedPaths
	Set-WorkflowValue -InputObject $session -Name 'PendingCommitMessage' -Value $commitMessage
	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'commit-pending'
	Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
	Invoke-CheckedNative -FilePath 'git' -Arguments @('commit', '-m', $commitMessage) | Out-Null
	$commitSha = (Invoke-CheckedNative -FilePath 'git' -Arguments @('rev-parse', 'HEAD') -CaptureOutput).Text
	Set-WorkflowValue -InputObject $session -Name 'CommitSha' -Value $commitSha
	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'committed'
	Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

	Write-Host ''
	Write-Host 'Rechecking origin/main immediately before the push...'
	Invoke-CheckedNative -FilePath 'git' -Arguments @('fetch', '--prune', 'origin', 'main') | Out-Null
	$remoteBeforePush = (Invoke-CheckedNative -FilePath 'git' -Arguments @(
		'rev-parse', 'refs/remotes/origin/main'
	) -CaptureOutput).Text
	if ($remoteBeforePush -ne $expectedRemoteCommit) {
		throw "origin/main changed before the push. The local commit $commitSha is safe, but it was not pushed. Reconcile the remote changes manually, then resume publication."
	}

	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
	$upstream = Invoke-CheckedNative -FilePath 'git' -Arguments @(
		'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'
	) -CaptureOutput -AllowFailure
	if ($upstream.ExitCode -ne 0 -or $upstream.Text -ne 'origin/main') {
		Invoke-CheckedNative -FilePath 'git' -Arguments @('push', '-u', 'origin', 'main') | Out-Null
	} else {
		Invoke-CheckedNative -FilePath 'git' -Arguments @('push', 'origin', 'main') | Out-Null
	}

	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'pushed'
	Set-WorkflowValue -InputObject $session -Name 'PushedAtUtc' -Value ([DateTime]::UtcNow.ToString('o'))
	Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

	$watcherPath = Join-Path $PSScriptRoot 'Watch-Deployment.ps1'
	& $watcherPath -CommitSha $commitSha
	if ($LASTEXITCODE -ne 0) {
		throw "The commit was pushed, but deployment monitoring did not finish successfully. Resume it with: powershell -NoProfile -File `"$watcherPath`" -CommitSha $commitSha"
	}
} finally {
	Pop-Location
}
