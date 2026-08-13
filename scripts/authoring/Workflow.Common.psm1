Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WorkflowRepositoryRoot {
	[CmdletBinding()]
	param()

	$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
	if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
		throw "The authoring toolkit is not inside the expected Git repository: $root"
	}
	return $root.TrimEnd('\', '/')
}

function Get-WorkflowStateDirectory {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	return (Join-Path $RepositoryRoot '.authoring-workflow')
}

function Get-WorkflowSessionPath {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	return (Join-Path (Get-WorkflowStateDirectory -RepositoryRoot $RepositoryRoot) 'session.json')
}

function Write-WorkflowTextAtomic {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$Content
	)

	$parent = Split-Path -Parent $Path
	if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
		New-Item -ItemType Directory -Path $parent -Force | Out-Null
	}
	$temporary = "$Path.tmp-$PID-$([Guid]::NewGuid().ToString('N'))"
	$encoding = New-Object Text.UTF8Encoding($false)
	try {
		[IO.File]::WriteAllText($temporary, $Content, $encoding)
		if (Test-Path -LiteralPath $Path -PathType Leaf) {
			$backup = "$Path.backup-$PID-$([Guid]::NewGuid().ToString('N'))"
			try {
				[IO.File]::Replace($temporary, $Path, $backup, $true)
				Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
			} catch {
				Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
				Move-Item -LiteralPath $temporary -Destination $Path -Force
			}
		} else {
			Move-Item -LiteralPath $temporary -Destination $Path
		}
	} finally {
		Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
	}
}

function Get-WorkflowProperty {
	[CmdletBinding()]
	param(
		[AllowNull()]
		[object]$InputObject,

		[Parameter(Mandatory = $true)]
		[string]$Name,

		[AllowNull()]
		[object]$Default = $null
	)

	if ($null -eq $InputObject) {
		return $Default
	}
	$property = @($InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Name }) |
		Select-Object -First 1
	if ($null -eq $property) {
		return $Default
	}
	return $property.Value
}

function Set-WorkflowProperty {
	[CmdletBinding()]
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
	if ($null -eq $property) {
		$InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
	} else {
		$property.Value = $Value
	}
	return $InputObject
}

function Read-WorkflowSession {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$path = Get-WorkflowSessionPath -RepositoryRoot $RepositoryRoot
	if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
		return $null
	}
	try {
		$session = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
	} catch {
		throw "The active authoring session is unreadable: $path`n$($_.Exception.Message)"
	}
	if ($null -eq $session -or -not (Get-WorkflowProperty -InputObject $session -Name 'Version')) {
		throw "The active authoring session is missing its version: $path"
	}
	return $session
}

function Write-WorkflowSession {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot),

		[Parameter(Mandatory = $true)]
		[object]$Session
	)

	Set-WorkflowProperty -InputObject $Session -Name 'UpdatedAtUtc' -Value ([DateTime]::UtcNow.ToString('o')) |
		Out-Null
	$json = $Session | ConvertTo-Json -Depth 20
	Write-WorkflowTextAtomic -Path (Get-WorkflowSessionPath -RepositoryRoot $RepositoryRoot) `
		-Content ($json + [Environment]::NewLine)
}

function Invoke-WorkflowNative {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath,

		[Alias('Arguments')]
		[string[]]$ArgumentList = @(),

		[string]$WorkingDirectory,

		[switch]$CaptureOutput,

		[switch]$AllowFailure
	)

	$oldLocation = $null
	$oldErrorActionPreference = $ErrorActionPreference
	if ($WorkingDirectory) {
		$oldLocation = Get-Location
		Set-Location -LiteralPath $WorkingDirectory
	}
	try {
		# Windows PowerShell 5.1 turns native stderr into error records. Native exit codes are
		# checked explicitly below, so stderr must not trigger ErrorActionPreference = Stop.
		$ErrorActionPreference = 'Continue'
		if ($CaptureOutput) {
			$rawOutput = @(& $FilePath @ArgumentList 2>&1)
			$exitCode = $LASTEXITCODE
			$lines = @($rawOutput | ForEach-Object { $_.ToString() })
		} else {
			& $FilePath @ArgumentList 2>&1 | ForEach-Object { Write-Host $_.ToString() }
			$exitCode = $LASTEXITCODE
			$lines = @()
		}
		$result = [pscustomobject]@{
			ExitCode = $exitCode
			Lines = $lines
			Output = ($lines -join [Environment]::NewLine).Trim()
			Text = ($lines -join [Environment]::NewLine).Trim()
		}
	} finally {
		$ErrorActionPreference = $oldErrorActionPreference
		if ($null -ne $oldLocation) {
			Set-Location -LiteralPath $oldLocation.Path
		}
	}
	if ($exitCode -ne 0 -and -not $AllowFailure) {
		$detail = ($lines -join [Environment]::NewLine).Trim()
		$message = "Command failed with exit code ${exitCode}: $FilePath $($ArgumentList -join ' ')"
		if ($detail) {
			$message += "`n$detail"
		}
		throw $message
	}
	return $result
}

function Get-WorkflowRelativePath {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$repositoryDirectory = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
	$root = $repositoryDirectory + [IO.Path]::DirectorySeparatorChar
	$absolute = if ([IO.Path]::IsPathRooted($Path)) {
		[IO.Path]::GetFullPath($Path)
	} else {
		[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Path))
	}
	if ($absolute.Equals($repositoryDirectory, [StringComparison]::OrdinalIgnoreCase)) {
		throw "A workflow path must identify a file or subdirectory, not the repository root: $Path"
	}
	if (-not $absolute.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
		throw "Path is outside the repository: $Path"
	}
	return $absolute.Substring($root.Length).Replace('\', '/')
}

function Add-WorkflowExpectedPath {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[object]$Session,

		[Parameter(Mandatory = $true)]
		[string]$Path,

		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$relative = Get-WorkflowRelativePath -Path $Path -RepositoryRoot $RepositoryRoot
	if ($relative -eq '.authoring-workflow' -or $relative.StartsWith('.authoring-workflow/')) {
		throw "Workflow state cannot be staged: $relative"
	}
	$paths = @((Get-WorkflowProperty -InputObject $Session -Name 'ExpectedPaths' -Default @()))
	$paths = @($paths + $relative | Where-Object { $_ } | Sort-Object -Unique)
	Set-WorkflowProperty -InputObject $Session -Name 'ExpectedPaths' -Value $paths | Out-Null
	return $Session
}

function Get-WorkflowChangedPaths {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$paths = New-Object Collections.Generic.List[string]
	$commands = @(
		@('-c', 'core.safecrlf=false', 'diff', '--name-only', '--diff-filter=ACDMRTUXB', 'HEAD', '--'),
		@('-c', 'core.safecrlf=false', 'diff', '--cached', '--name-only', '--diff-filter=ACDMRTUXB', '--'),
		@('-c', 'core.safecrlf=false', 'ls-files', '--others', '--exclude-standard')
	)
	foreach ($arguments in $commands) {
		$result = Invoke-WorkflowNative -FilePath 'git' -ArgumentList $arguments `
			-WorkingDirectory $RepositoryRoot -CaptureOutput
		foreach ($line in $result.Lines) {
			$normalized = $line.Trim().Replace('\', '/')
			if ($normalized -match '^warning:\s') {
				continue
			}
			if ($normalized) {
				$paths.Add($normalized)
			}
		}
	}
	return @($paths | Sort-Object -Unique)
}

function Assert-NoUnexpectedWorkflowChanges {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot),

		[object]$Session,

		[string[]]$ExpectedPaths
	)

	if ($null -eq $ExpectedPaths) {
		if ($null -eq $Session) {
			throw 'A workflow session or explicit expected-path list is required.'
		}
		$ExpectedPaths = @((Get-WorkflowProperty -InputObject $Session -Name 'ExpectedPaths' -Default @()))
	}
	$expected = @($ExpectedPaths | ForEach-Object {
			Get-WorkflowRelativePath -Path ([string]$_) -RepositoryRoot $RepositoryRoot
		} | Sort-Object -Unique)
	$changed = @(Get-WorkflowChangedPaths -RepositoryRoot $RepositoryRoot)
	$unexpected = @($changed | Where-Object { $expected -notcontains $_ })
	if ($unexpected.Count -gt 0) {
		throw "Unrelated changes are present and are not part of this authoring batch:`n$($unexpected -join "`n")`nAdd them through the workflow or handle them before publishing."
	}
	return $true
}

function Test-WorkflowCommand {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name
	)

	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-WorkflowCanonicalOrigins {
	[CmdletBinding()]
	param()

	return @(
		'https://github.com/briansgithub/briansgithub.github.io',
		'https://github.com/briansgithub/briansgithub.github.io.git',
		'git@github.com:briansgithub/briansgithub.github.io',
		'git@github.com:briansgithub/briansgithub.github.io.git',
		'ssh://git@github.com/briansgithub/briansgithub.github.io',
		'ssh://git@github.com/briansgithub/briansgithub.github.io.git'
	)
}

function Assert-WorkflowCanonicalOrigin {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$origin = Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
		'remote', 'get-url', 'origin'
	) -WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
	$acceptedOrigins = @(Get-WorkflowCanonicalOrigins)
	if ($origin.ExitCode -ne 0 -or $acceptedOrigins -notcontains $origin.Text) {
		$actual = if ($origin.Text) { $origin.Text } else { '(unavailable)' }
		throw "Publication is restricted to the canonical website repository. Expected briansgithub/briansgithub.github.io, but origin is $actual."
	}
	return $origin.Text
}

function Assert-WorkflowHooks {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$hooks = Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
		'config', '--get', 'core.hooksPath'
	) -WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
	$requiredHooks = @(
		(Join-Path $RepositoryRoot '.githooks\pre-commit'),
		(Join-Path $RepositoryRoot '.githooks\pre-push')
	)
	$missingHooks = @($requiredHooks | Where-Object {
			-not (Test-Path -LiteralPath $_ -PathType Leaf)
		})
	if ($hooks.ExitCode -ne 0 -or $hooks.Text -ne '.githooks' -or $missingHooks.Count -gt 0) {
		throw 'The versioned Git safety hooks are not fully enabled. Run npm run setup:hooks, restore any missing .githooks files, and review the batch again.'
	}
	return $true
}

function Show-WorkflowDiagnostics {
	[CmdletBinding()]
	param(
		[string]$RepositoryRoot = (Get-WorkflowRepositoryRoot)
	)

	$checks = New-Object Collections.Generic.List[object]
	$checks.Add([pscustomobject]@{
		Check = 'Windows PowerShell 5.1'
		Passed = ($PSVersionTable.PSEdition -eq 'Desktop' -and
			$PSVersionTable.PSVersion.Major -eq 5 -and
			$PSVersionTable.PSVersion.Minor -ge 1)
		Detail = "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
	})
	foreach ($command in @('powershell.exe', 'node', 'npm.cmd', 'git', 'gh', 'code')) {
		$checks.Add([pscustomobject]@{
			Check = $command
			Passed = (Test-WorkflowCommand -Name $command)
			Detail = if (Test-WorkflowCommand -Name $command) {
				(Get-Command $command).Source
			} else {
				'Not found on PATH'
			}
		})
	}
	$nodeMajor = $null
	if (Test-WorkflowCommand -Name 'node') {
		$nodeResult = Invoke-WorkflowNative -FilePath 'node' -ArgumentList @('--version') `
			-WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
		$nodeMajor = if ($nodeResult.Text -match '^v(\d+)') { [int]$Matches[1] } else { 0 }
		$checks.Add([pscustomobject]@{
			Check = 'Node 24'
			Passed = ($nodeResult.ExitCode -eq 0 -and $nodeMajor -eq 24)
			Detail = $nodeResult.Text
		})
	}
	if (Test-WorkflowCommand -Name 'git') {
		$branch = Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('branch', '--show-current') `
			-WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
		$checks.Add([pscustomobject]@{
			Check = 'Git branch main'
			Passed = ($branch.ExitCode -eq 0 -and $branch.Text -eq 'main')
			Detail = $branch.Text
		})
		$status = @(Get-WorkflowChangedPaths -RepositoryRoot $RepositoryRoot)
		$checks.Add([pscustomobject]@{
			Check = 'Working tree'
			Passed = ($status.Count -eq 0)
			Detail = if ($status.Count -eq 0) { 'Clean' } else { "$($status.Count) changed path(s)" }
		})
		$origin = Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'remote', 'get-url', 'origin'
		) -WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
		$acceptedOrigins = @(Get-WorkflowCanonicalOrigins)
		$checks.Add([pscustomobject]@{
			Check = 'Git origin'
			Passed = ($origin.ExitCode -eq 0 -and $acceptedOrigins -contains $origin.Text)
			Detail = if ($origin.Text) { $origin.Text } else { 'origin is unavailable' }
		})
		$hooks = Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'config', '--get', 'core.hooksPath'
		) -WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
		$hookFilesPresent = (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.githooks\pre-commit') `
			-PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.githooks\pre-push') `
			-PathType Leaf)
		$checks.Add([pscustomobject]@{
			Check = 'Git hooks'
			Passed = ($hooks.ExitCode -eq 0 -and $hooks.Text -eq '.githooks' -and $hookFilesPresent)
			Detail = if ($hooks.Text -eq '.githooks' -and $hookFilesPresent) {
				'.githooks; pre-commit and pre-push present'
			} else {
				'Will be configured or repaired when a batch starts'
			}
		})
	}
	$dependenciesPresent = Test-Path -LiteralPath (Join-Path $RepositoryRoot 'node_modules') `
		-PathType Container
	$dependencyCheck = if ($dependenciesPresent -and (Test-WorkflowCommand -Name 'npm.cmd')) {
		Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('ls', '--depth=0') `
			-WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
	} else {
		$null
	}
	$dependenciesReady = $null -ne $dependencyCheck -and $dependencyCheck.ExitCode -eq 0
	$checks.Add([pscustomobject]@{
		Check = 'Locked dependencies'
		Passed = $dependenciesReady
		Detail = if ($dependenciesReady) {
			'Ready; npm dependency tree is valid'
		} elseif ($dependenciesPresent) {
			'npm dependency tree needs repair; npm ci will run when a batch starts'
		} else {
			'Not installed; npm ci will run when a batch starts'
		}
	})
	if (Test-WorkflowCommand -Name 'gh') {
		$auth = Invoke-WorkflowNative -FilePath 'gh' -ArgumentList @('auth', 'status') `
			-WorkingDirectory $RepositoryRoot -CaptureOutput -AllowFailure
		$checks.Add([pscustomobject]@{
			Check = 'GitHub authentication'
			Passed = ($auth.ExitCode -eq 0)
			Detail = if ($auth.ExitCode -eq 0) { 'Authenticated' } else { 'Run gh auth login' }
		})
	}
	$obsidianCandidates = @(
		(Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
		(Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'),
		(Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe')
	)
	$obsidian = @($obsidianCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }) |
		Select-Object -First 1
	$checks.Add([pscustomobject]@{
		Check = 'Obsidian (optional)'
		Passed = $null -ne $obsidian
		Detail = if ($obsidian) { $obsidian } else { 'Not installed; VS Code remains available' }
	})

	Write-Host 'Website authoring diagnostics' -ForegroundColor Cyan
	foreach ($check in $checks) {
		$marker = if ($check.Passed) { '[OK]' } else { '[--]' }
		$color = if ($check.Passed) { 'Green' } else { 'Yellow' }
		Write-Host ("{0} {1}: {2}" -f $marker, $check.Check, $check.Detail) -ForegroundColor $color
	}
	$requiredFailures = @($checks | Where-Object {
			-not $_.Passed -and $_.Check -notin @(
				'Working tree',
				'Git hooks',
				'Locked dependencies',
				'Obsidian (optional)'
			)
		})
	return [pscustomobject]@{
		Passed = ($requiredFailures.Count -eq 0)
		Checks = @($checks | ForEach-Object { $_ })
	}
}

Export-ModuleMember -Function @(
	'Get-WorkflowRepositoryRoot',
	'Get-WorkflowStateDirectory',
	'Get-WorkflowSessionPath',
	'Write-WorkflowTextAtomic',
	'Get-WorkflowProperty',
	'Set-WorkflowProperty',
	'Read-WorkflowSession',
	'Write-WorkflowSession',
	'Invoke-WorkflowNative',
	'Get-WorkflowRelativePath',
	'Add-WorkflowExpectedPath',
	'Get-WorkflowChangedPaths',
	'Assert-NoUnexpectedWorkflowChanges',
	'Test-WorkflowCommand',
	'Assert-WorkflowCanonicalOrigin',
	'Assert-WorkflowHooks',
	'Show-WorkflowDiagnostics'
)
