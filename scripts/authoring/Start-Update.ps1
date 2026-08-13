#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$Diagnostics
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workflow.Common.psm1') -Force

function Read-MenuChoice {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Prompt,

		[Parameter(Mandatory = $true)]
		[int]$Minimum,

		[Parameter(Mandatory = $true)]
		[int]$Maximum
	)

	do {
		$answer = Read-Host $Prompt
		$value = 0
		$valid = [int]::TryParse($answer, [ref]$value) -and $value -ge $Minimum -and $value -le $Maximum
		if (-not $valid) {
			Write-Warning "Enter a number from $Minimum through $Maximum."
		}
	} until ($valid)
	return $value
}

function ConvertTo-ContentSlug {
	param([Parameter(Mandatory = $true)][string]$Value)

	$normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
	$builder = New-Object Text.StringBuilder
	foreach ($character in $normalized.ToCharArray()) {
		if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne
			[Globalization.UnicodeCategory]::NonSpacingMark) {
			[void]$builder.Append($character)
		}
	}
	$slug = $builder.ToString().ToLowerInvariant().Replace('&', ' and ')
	$slug = $slug -replace '[^a-z0-9]+', '-'
	$slug = $slug -replace '^-+|-+$', ''
	return ($slug -replace '-{2,}', '-')
}

function Test-PublicMarkdownPublished {
	param([Parameter(Mandatory = $true)][string]$Path)

	if ([IO.Path]::GetExtension($Path) -notin @('.md', '.mdx')) {
		return $true
	}
	$content = [IO.File]::ReadAllText($Path)
	$frontmatter = [regex]::Match(
		$content,
		'\A---\r?\n(?<yaml>[\s\S]*?)\r?\n---(?:\r?\n|$)'
	)
	return $frontmatter.Success -and
		[regex]::IsMatch($frontmatter.Groups['yaml'].Value, '(?m)^draft:\s*false\s*$')
}

function Get-ContentDefinition {
	param([Parameter(Mandatory = $true)][int]$Choice)

	switch ($Choice) {
		1 { return [pscustomobject]@{ Label = 'Blog post'; Kind = 'writing'; HelperType = 'writing'; Folder = 'writing'; RoutePrefix = '/blog/' } }
		2 { return [pscustomobject]@{ Label = 'Project'; Kind = 'project'; HelperType = 'project'; Folder = 'projects'; RoutePrefix = '/projects/' } }
		3 { return [pscustomobject]@{ Label = '3D print'; Kind = 'print'; HelperType = 'print'; Folder = 'prints'; RoutePrefix = '/prints/' } }
		4 { return [pscustomobject]@{ Label = 'Book note'; Kind = 'book'; HelperType = 'book'; Folder = 'books'; RoutePrefix = '/books/' } }
		5 { return [pscustomobject]@{ Label = 'Quote'; Kind = 'quote'; HelperType = 'quotation'; Folder = 'quotes'; RoutePrefix = '/quotes/' } }
	}
}

function Add-SessionItem {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$items = @((Get-WorkflowProperty -InputObject $Session -Name 'Items' -Default @()))
	$duplicate = @($items | Where-Object {
			$_.PublicPath -eq $Item.PublicPath -or ($Item.DraftPath -and $_.DraftPath -eq $Item.DraftPath)
		})
	if ($duplicate.Count -gt 0) {
		Write-Warning 'That content is already in the active batch.'
		return $Session
	}
	$items += $Item
	Set-WorkflowProperty -InputObject $Session -Name 'Items' -Value $items | Out-Null
	Add-WorkflowExpectedPath -Session $Session -Path $Item.PublicPath -RepositoryRoot $RepositoryRoot |
		Out-Null
	return $Session
}

function Select-ExistingFile {
	param(
		[Parameter(Mandatory = $true)][object]$Definition,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$contentRoot = Join-Path $RepositoryRoot 'src\content'
	$files = @(
		Get-ChildItem -LiteralPath (Join-Path $contentRoot $Definition.Folder) -File `
			-ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.md', '.mdx') }
		Get-ChildItem -LiteralPath (Join-Path $contentRoot "_drafts\$($Definition.Folder)") -File `
			-ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.md', '.mdx') }
	) | Sort-Object FullName
	if ($files.Count -eq 0) {
		Write-Warning "No existing $($Definition.Label.ToLowerInvariant()) files were found."
		return $null
	}
	Write-Host ''
	for ($index = 0; $index -lt $files.Count; $index++) {
		$relative = Get-WorkflowRelativePath -Path $files[$index].FullName -RepositoryRoot $RepositoryRoot
		Write-Host ("  {0}. {1}" -f ($index + 1), $relative)
	}
	$choice = Read-MenuChoice -Prompt 'Choose a file' -Minimum 1 -Maximum $files.Count
	return $files[$choice - 1]
}

function Open-WorkflowEditor {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$paths = @((Get-WorkflowProperty -InputObject $Session -Name 'Items' -Default @()) |
		ForEach-Object { if ($_.DraftPath) { $_.DraftPath } else { $_.PublicPath } } |
		Sort-Object -Unique)
	if ($paths.Count -eq 0) {
		return
	}
	$arguments = @('-r') + @($paths | ForEach-Object { Join-Path $RepositoryRoot $_ })
	Start-Process -FilePath 'code' -ArgumentList $arguments | Out-Null
	Write-Host ''
	Write-Host 'Opened the batch in VS Code.' -ForegroundColor Green
	Write-Host 'Write and save your content, then rerun: npm run content:workflow'
}

function Open-ObsidianVault {
	param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

	$candidates = @(
		(Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
		(Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'),
		(Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe')
	)
	$executable = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }) |
		Select-Object -First 1
	if (-not $executable) {
		Write-Warning 'Obsidian was not found. VS Code remains the supported default.'
		return
	}
	$vaultPath = Join-Path $RepositoryRoot 'src\content'
	$uri = 'obsidian://open?path=' + [Uri]::EscapeDataString($vaultPath)
	Start-Process -FilePath $executable -ArgumentList $uri | Out-Null
	Write-Host 'Opened the content vault in Obsidian.' -ForegroundColor Green
}

$repositoryRoot = Get-WorkflowRepositoryRoot
Push-Location $repositoryRoot
try {
	if ($Diagnostics) {
		$result = Show-WorkflowDiagnostics -RepositoryRoot $repositoryRoot
		if (-not $result.Passed) {
			throw 'One or more required authoring prerequisites are unavailable.'
		}
		return
	}

	$diagnosticResult = Show-WorkflowDiagnostics -RepositoryRoot $repositoryRoot
	if (-not $diagnosticResult.Passed) {
		throw 'Resolve the failed prerequisite checks before starting an authoring session.'
	}
	$branch = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('branch', '--show-current') `
		-WorkingDirectory $repositoryRoot -CaptureOutput).Text
	if ($branch -ne 'main') {
		throw "The guided workflow starts only on main. Current branch: $branch"
	}

		$session = Read-WorkflowSession -RepositoryRoot $repositoryRoot
		if ($null -eq $session) {
		$changed = @(Get-WorkflowChangedPaths -RepositoryRoot $repositoryRoot)
		if ($changed.Count -gt 0) {
			throw "A new content batch needs a clean starting point, but these uncommitted website changes already exist:`n  $($changed -join "`n  ")`nCommit or otherwise handle them first, then run the launcher again."
		}
		Write-Host 'Synchronizing safely with origin/main...'
		Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('fetch', '--prune', 'origin', 'main') `
			-WorkingDirectory $repositoryRoot | Out-Null
		$counts = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-list', '--left-right', '--count', 'origin/main...HEAD'
		) -WorkingDirectory $repositoryRoot -CaptureOutput).Text -split '\s+'
		$behind = [int]$counts[0]
		$ahead = [int]$counts[1]
		if ($behind -gt 0 -and $ahead -gt 0) {
			throw 'Local main and origin/main have diverged. Reconcile them manually before authoring.'
		}
		if ($behind -gt 0) {
			Write-Host "Fast-forwarding local main by $behind commit(s)..."
			Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('merge', '--ff-only', 'origin/main') `
				-WorkingDirectory $repositoryRoot | Out-Null
		}
		if ($ahead -gt 0) {
			Write-Warning "Local main already has $ahead outgoing commit(s); they will be shown again before publication."
			Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
				'log', '--oneline', 'origin/main..HEAD'
			) -WorkingDirectory $repositoryRoot | Out-Null
		}
		$hookPath = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'config', '--get', 'core.hooksPath'
		) -WorkingDirectory $repositoryRoot -CaptureOutput -AllowFailure).Text
		if ($hookPath -ne '.githooks') {
			Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('run', 'setup:hooks') `
				-WorkingDirectory $repositoryRoot | Out-Null
		}
		Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
		$dependencyCheck = Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @(
			'ls', '--depth=0'
		) -WorkingDirectory $repositoryRoot -CaptureOutput -AllowFailure
		if ($dependencyCheck.ExitCode -ne 0) {
			Write-Host 'Installing the locked project dependencies...'
			Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('ci') `
				-WorkingDirectory $repositoryRoot | Out-Null
		}
		$head = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') `
			-WorkingDirectory $repositoryRoot -CaptureOutput).Text
		$remote = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('rev-parse', 'origin/main') `
			-WorkingDirectory $repositoryRoot -CaptureOutput).Text
		$session = [pscustomobject]@{
			Version = 1
			SessionId = [Guid]::NewGuid().ToString('N')
			CreatedAtUtc = [DateTime]::UtcNow.ToString('o')
			UpdatedAtUtc = [DateTime]::UtcNow.ToString('o')
			Status = 'editing'
			Branch = 'main'
			StartingCommit = $head
			RemoteCommit = $remote
			Items = @()
			Assets = @()
			ExpectedPaths = @()
			Verification = [pscustomobject]@{ Status = 'not-run' }
			CommitSha = $null
			ActionsRunId = $null
			SuggestedCommitMessage = 'Update website content'
		}
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
		Write-Host 'Created a restartable authoring batch.' -ForegroundColor Green
	} else {
		Write-Host "Resuming authoring batch $($session.SessionId)." -ForegroundColor Green
		if ([string]$session.Status -in @('commit-pending', 'committed', 'pushed', 'deploying', 'published')) {
			throw "This batch is already '$($session.Status)'. Use Publish or Resume deployment monitoring instead of adding more edits."
		}
		$currentHead = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('rev-parse', 'HEAD') `
			-WorkingDirectory $repositoryRoot -CaptureOutput).Text
		if (-not $session.StartingCommit -or $currentHead -ne [string]$session.StartingCommit) {
			throw "Local main changed after this batch began. Expected $($session.StartingCommit), but HEAD is $currentHead. Reconcile this manually before resuming."
		}
		Write-Host 'Rechecking origin/main before extending the batch...'
		Invoke-WorkflowNative -FilePath 'git' -ArgumentList @('fetch', '--prune', 'origin', 'main') `
			-WorkingDirectory $repositoryRoot | Out-Null
		$currentRemote = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-parse', 'origin/main'
		) -WorkingDirectory $repositoryRoot -CaptureOutput).Text
		if (-not $session.RemoteCommit -or $currentRemote -ne [string]$session.RemoteCommit) {
			throw "origin/main changed after this batch began. Expected $($session.RemoteCommit), but found $currentRemote. Reconcile the remote changes manually before continuing."
		}
		$outgoing = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'rev-list', '--count', 'origin/main..HEAD'
		) -WorkingDirectory $repositoryRoot -CaptureOutput).Text
		if ([int]$outgoing -gt 0) {
			Write-Warning "Local main has $outgoing outgoing commit(s); they will be included in the eventual push."
			Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
				'log', '--oneline', 'origin/main..HEAD'
			) -WorkingDirectory $repositoryRoot | Out-Null
		}
		$hookPath = (Invoke-WorkflowNative -FilePath 'git' -ArgumentList @(
			'config', '--get', 'core.hooksPath'
		) -WorkingDirectory $repositoryRoot -CaptureOutput -AllowFailure).Text
		if ($hookPath -ne '.githooks') {
			Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('run', 'setup:hooks') `
				-WorkingDirectory $repositoryRoot | Out-Null
		}
		Assert-WorkflowHooks -RepositoryRoot $repositoryRoot | Out-Null
		$dependencyCheck = Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @(
			'ls', '--depth=0'
		) -WorkingDirectory $repositoryRoot -CaptureOutput -AllowFailure
		if ($dependencyCheck.ExitCode -ne 0) {
			Write-Host 'Repairing the locked project dependencies...'
			Invoke-WorkflowNative -FilePath 'npm.cmd' -ArgumentList @('ci') `
				-WorkingDirectory $repositoryRoot | Out-Null
		}
		$expected = @((Get-WorkflowProperty -InputObject $session -Name 'ExpectedPaths' -Default @()))
			$changed = @(Get-WorkflowChangedPaths -RepositoryRoot $repositoryRoot)
			$unexpected = @($changed | Where-Object { $expected -notcontains $_ })
			if ($unexpected.Count -gt 0) {
				Write-Warning 'These changed files are not yet recorded in the active batch:'
				$unexpected | ForEach-Object { Write-Host "  $_" }
				$answer = Read-Host 'Type INCLUDE to add every listed file to this batch, or press Enter to stop'
				if ($answer -cne 'INCLUDE') {
					throw 'The active session was left unchanged. Handle the unrelated files or rerun and include them explicitly.'
				}
				foreach ($path in $unexpected) {
					Add-WorkflowExpectedPath -Session $session -Path $path -RepositoryRoot $repositoryRoot |
						Out-Null
				}
				Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
			}
		}
	Set-WorkflowProperty -InputObject $session -Name 'Status' -Value 'editing' | Out-Null
	Set-WorkflowProperty -InputObject $session -Name 'Verification' -Value ([pscustomobject]@{
		Status = 'not-run'
		Message = 'The batch was reopened for editing and must be reviewed again.'
	}) | Out-Null
	Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

	$done = $false
	while (-not $done) {
		Write-Host ''
		Write-Host 'Add content to this batch' -ForegroundColor Cyan
		Write-Host '  1. New Blog post'
		Write-Host '  2. New Project'
		Write-Host '  3. New 3D print'
		Write-Host '  4. New Book note'
		Write-Host '  5. New Quote'
		Write-Host '  6. Edit existing Blog/Project/Print/Book/Quote'
		Write-Host '  7. Edit About page'
		Write-Host '  8. Edit site identity'
		Write-Host '  9. Edit resume data'
		Write-Host ' 10. Open optional Obsidian vault'
		Write-Host '  0. Open batch in VS Code and finish this phase'
		$choice = Read-MenuChoice -Prompt 'Choose an action' -Minimum 0 -Maximum 10
		if ($choice -eq 0) {
			$done = $true
			continue
		}
		if ($choice -eq 10) {
			Open-ObsidianVault -RepositoryRoot $repositoryRoot
			continue
		}

		$item = $null
		if ($choice -ge 1 -and $choice -le 5) {
			$definition = Get-ContentDefinition -Choice $choice
			$title = (Read-Host "$($definition.Label) title").Trim()
			if (-not $title) {
				Write-Warning 'A title is required.'
				continue
			}
			$defaultSlug = ConvertTo-ContentSlug -Value $title
			$slug = (Read-Host "Lowercase kebab-case slug [$defaultSlug]").Trim()
			if (-not $slug) { $slug = $defaultSlug }
			if ($slug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
				Write-Warning 'Use a lowercase kebab-case slug.'
				continue
			}
			Invoke-WorkflowNative -FilePath 'node' -ArgumentList @(
				'scripts/new-content.mjs', $definition.HelperType, $slug, '--title', $title
			) -WorkingDirectory $repositoryRoot | Out-Null
			$draftPath = "src/content/_drafts/$($definition.Folder)/$slug.md"
			$publicPath = "src/content/$($definition.Folder)/$slug.md"
			$item = [pscustomobject]@{
				Id = [Guid]::NewGuid().ToString('N')
				Kind = $definition.Kind
				Mode = 'new'
				Title = $title
				DraftPath = $draftPath
				PublicPath = $publicPath
				Route = if ($definition.Kind -eq 'quote') { '/quotes/' } else { "$($definition.RoutePrefix)$slug/" }
				Promoted = $false
			}
		} elseif ($choice -eq 6) {
			Write-Host '  1. Blog  2. Project  3. 3D print  4. Book note  5. Quote'
			$typeChoice = Read-MenuChoice -Prompt 'Content type' -Minimum 1 -Maximum 5
			$definition = Get-ContentDefinition -Choice $typeChoice
			$file = Select-ExistingFile -Definition $definition -RepositoryRoot $repositoryRoot
			if ($null -eq $file) { continue }
			$relative = Get-WorkflowRelativePath -Path $file.FullName -RepositoryRoot $repositoryRoot
			$isDraft = $relative.StartsWith('src/content/_drafts/')
			$isPublished = -not $isDraft -and (Test-PublicMarkdownPublished -Path $file.FullName)
			$slug = [IO.Path]::GetFileNameWithoutExtension($file.Name)
			$publicPath = "src/content/$($definition.Folder)/$slug$($file.Extension)"
			$item = [pscustomobject]@{
				Id = [Guid]::NewGuid().ToString('N')
				Kind = $definition.Kind
				Mode = 'existing'
				Title = $slug
				DraftPath = if ($isDraft) { $relative } else { $null }
				PublicPath = $publicPath
				Route = if ($definition.Kind -eq 'quote') { '/quotes/' } else { "$($definition.RoutePrefix)$slug/" }
				Promoted = $isPublished
			}
		} else {
			switch ($choice) {
				7 { $path = 'src/content/pages/about.md'; $kind = 'about'; $route = '/'; $title = 'About' }
				8 { $path = 'src/data/site.ts'; $kind = 'site'; $route = '/'; $title = 'Site identity' }
				9 { $path = 'src/data/resume.ts'; $kind = 'resume'; $route = '/resume/'; $title = 'Resume' }
			}
			$item = [pscustomobject]@{
				Id = [Guid]::NewGuid().ToString('N')
				Kind = $kind
				Mode = 'existing'
				Title = $title
				DraftPath = $null
				PublicPath = $path
				Route = $route
				Promoted = $true
			}
		}
		$session = Add-SessionItem -Session $session -Item $item -RepositoryRoot $repositoryRoot
		Set-WorkflowProperty -InputObject $session -Name 'Status' -Value 'editing' | Out-Null
		Set-WorkflowProperty -InputObject $session -Name 'Verification' -Value ([pscustomobject]@{
			Status = 'not-run'
			Message = 'The authoring batch changed after the previous review.'
		}) | Out-Null
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
	}

	$items = @((Get-WorkflowProperty -InputObject $session -Name 'Items' -Default @()))
	if ($items.Count -eq 0) {
		Write-Warning 'The batch is empty. Rerun the workflow when you are ready to add content.'
		return
	}
	Open-WorkflowEditor -Session $session -RepositoryRoot $repositoryRoot
} finally {
	Pop-Location
}
