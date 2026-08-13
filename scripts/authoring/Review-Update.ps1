#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$SkipBrowser,

	[switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'Workflow.Common.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
	throw "The shared authoring module was not found: $modulePath"
}
Import-Module $modulePath -Force

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
	foreach ($propertyName in $Names) {
		$property = @(
			$InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $propertyName }
		) | Select-Object -First 1
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

	$property = @(
		$InputObject.PSObject.Properties | Where-Object { $_.Name -ieq $Name }
	) | Select-Object -First 1
	if ($null -ne $property) {
		$property.Value = $Value
		return
	}
	$InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

function Invoke-CheckedNative {
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath,

		[Parameter(Mandatory = $true)]
		[string[]]$Arguments,

		[Parameter(Mandatory = $true)]
		[string]$WorkingDirectory,

		[switch]$CaptureOutput,

		[switch]$AllowFailure
	)

	Push-Location $WorkingDirectory
	$previousErrorActionPreference = $ErrorActionPreference
	try {
		$ErrorActionPreference = 'Continue'
		$commandOutput = @(& $FilePath @Arguments 2>&1)
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
		Pop-Location
	}
	$outputLines = @($commandOutput | ForEach-Object { $_.ToString() })
	if (-not $CaptureOutput) {
		$outputLines | ForEach-Object { Write-Host $_ }
	}
	if ($exitCode -ne 0 -and -not $AllowFailure) {
		$detail = ($outputLines -join [Environment]::NewLine).Trim()
		if ($detail) {
			throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$detail"
		}
		throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
	}
	return [pscustomobject]@{
		ExitCode = $exitCode
		Lines = $outputLines
		Text = ($outputLines -join [Environment]::NewLine).Trim()
	}
}

function Resolve-RepositoryPath {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
	if ([IO.Path]::IsPathRooted($Path)) {
		$resolved = [IO.Path]::GetFullPath($Path)
	} else {
		$resolved = [IO.Path]::GetFullPath((Join-Path $root $Path))
	}
	$prefix = $root + [IO.Path]::DirectorySeparatorChar
	if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
		throw "The workflow path is outside the repository: $Path"
	}
	return $resolved
}

function Get-RepositoryRelativePath {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$absolute = Resolve-RepositoryPath -Path $Path -RepositoryRoot $RepositoryRoot
	$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
	return $absolute.Substring($root.Length + 1).Replace('\', '/')
}

function Add-ExpectedWorkflowPath {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$Path
	)

	$normalized = $Path.Replace('\', '/').TrimStart('/')
	$commonCommand = Get-Command Add-WorkflowExpectedPath -ErrorAction SilentlyContinue
	if ($null -ne $commonCommand) {
		$result = Add-WorkflowExpectedPath -Session $Session -Path $normalized
		if ($null -ne $result) {
			return $result
		}
		return $Session
	}
	$existing = @(Get-WorkflowValue -InputObject $Session -Names @(
		'ExpectedPaths', 'ExpectedGitPaths', 'TrackedPaths'
	))
	Set-WorkflowValue -InputObject $Session -Name 'ExpectedPaths' -Value @(
		$existing + $normalized | Where-Object { $_ } | Sort-Object -Unique
	)
	return $Session
}

function Get-NormalizedItemKind {
	param([Parameter(Mandatory = $true)][object]$Item)

	$kind = [string](Get-WorkflowValue -InputObject $Item -Names @(
		'Kind', 'ContentType', 'Type', 'Collection'
	))
	switch -Regex ($kind.ToLowerInvariant()) {
		'^(blog|writing|post|article)$' { return 'writing' }
		'^(project|projects)$' { return 'projects' }
		'^(print|prints|3d-print|3d-model)$' { return 'prints' }
		'^(book|books|book-note)$' { return 'books' }
		'^(quote|quotes|quotation)$' { return 'quotes' }
		'^(about|about-page)$' { return 'about' }
		'^(site|identity|site-identity)$' { return 'site' }
		'^resume$' { return 'resume' }
		default { return $kind.ToLowerInvariant() }
	}
}

function Get-ItemDraftPath {
	param([Parameter(Mandatory = $true)][object]$Item)

	return [string](Get-WorkflowValue -InputObject $Item -Names @(
		'DraftPath', 'SourcePath', 'WorkingPath'
	))
}

function Get-ItemPublicPath {
	param([Parameter(Mandatory = $true)][object]$Item)

	return [string](Get-WorkflowValue -InputObject $Item -Names @(
		'PublicPath', 'DestinationPath', 'PublishedPath', 'TargetPath'
	))
}

function Test-PrivateDraftItem {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$draftPath = Get-ItemDraftPath -Item $Item
	if (-not $draftPath) {
		return $false
	}
	$relative = Get-RepositoryRelativePath -Path $draftPath -RepositoryRoot $RepositoryRoot
	return $relative -match '^src/content/_drafts/.+\.mdx?$'
}

function Get-ContentDraftState {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$absolute = Resolve-RepositoryPath -Path $Path -RepositoryRoot $RepositoryRoot
	if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
		return 'file-missing'
	}
	if ([IO.Path]::GetExtension($absolute) -notin @('.md', '.mdx')) {
		return 'not-markdown'
	}
	$content = [IO.File]::ReadAllText($absolute)
	$frontmatter = [regex]::Match(
		$content,
		'\A---\r?\n(?<yaml>[\s\S]*?)\r?\n---(?:\r?\n|$)'
	)
	if (-not $frontmatter.Success) {
		return 'frontmatter-missing'
	}
	$draft = [regex]::Match($frontmatter.Groups['yaml'].Value, '(?m)^draft:\s*(true|false)\s*$')
	if (-not $draft.Success) {
		return 'field-missing'
	}
	return $draft.Groups[1].Value.ToLowerInvariant()
}

function Get-PublicPathFromDraft {
	param(
		[Parameter(Mandatory = $true)][string]$DraftPath,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$relative = Get-RepositoryRelativePath -Path $DraftPath -RepositoryRoot $RepositoryRoot
	if ($relative -notmatch '^src/content/_drafts/(?<collection>[^/]+)/(?<remainder>.+\.mdx?)$') {
		throw "Cannot derive a public collection path from private draft: $relative"
	}
	return "src/content/$($Matches.collection)/$($Matches.remainder)"
}

function Get-ItemRoute {
	param([Parameter(Mandatory = $true)][object]$Item)

	$route = [string](Get-WorkflowValue -InputObject $Item -Names @(
		'Route', 'PublicRoute', 'UrlPath'
	))
	if ($route) {
		if ($route -match '^https?://') {
			return ([Uri]$route).PathAndQuery
		}
		if (-not $route.StartsWith('/')) {
			$route = "/$route"
		}
		return $route
	}

	$kind = Get-NormalizedItemKind -Item $Item
	$publicPath = Get-ItemPublicPath -Item $Item
	$slug = if ($publicPath) { [IO.Path]::GetFileNameWithoutExtension($publicPath) } else { '' }
	switch ($kind) {
		'writing' { return "/blog/$slug/" }
		'projects' { return "/projects/$slug/" }
		'prints' { return "/prints/$slug/" }
		'books' { return "/books/$slug/" }
		'quotes' { return '/quotes/' }
		'about' { return '/' }
		'site' { return '/' }
		'resume' { return '/resume/' }
		default { return '/' }
	}
}

function Get-ExpectedPaths {
	param([Parameter(Mandatory = $true)][object]$Session)

	return @(
		@(Get-WorkflowValue -InputObject $Session -Names @(
			'ExpectedPaths', 'ExpectedGitPaths', 'TrackedPaths'
		)) |
			ForEach-Object { ([string]$_).Replace('\', '/').TrimStart('/') } |
			Where-Object { $_ } |
			Sort-Object -Unique
	)
}

function Set-VerificationState {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$Status,
		[string]$Message
	)

	$verification = [ordered]@{
		Status = $Status
		VerifiedAtUtc = [DateTime]::UtcNow.ToString('o')
	}
	if ($Message) {
		$verification.Message = $Message
	}
	Set-WorkflowValue -InputObject $Session -Name 'Verification' -Value (
		[pscustomobject]$verification
	)
}

function Precheck-PrivateDrafts {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$failures = New-Object System.Collections.Generic.List[string]
	foreach ($item in $Items) {
		$draftPath = Get-ItemDraftPath -Item $item
		$draftRelative = Get-RepositoryRelativePath -Path $draftPath -RepositoryRoot $RepositoryRoot
		$publicRelative = Get-PublicPathFromDraft -DraftPath $draftPath `
			-RepositoryRoot $RepositoryRoot
		$publicAbsolute = Resolve-RepositoryPath -Path $publicRelative `
			-RepositoryRoot $RepositoryRoot
		Write-Host "Checking $draftRelative..."
		if (Test-Path -LiteralPath $publicAbsolute -PathType Leaf) {
			$failures.Add("${draftRelative}:`nThe destination already exists: $publicRelative")
			continue
		}
		$result = Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot `
			-Arguments @('scripts/publish-content.mjs', $draftRelative, '--check') `
			-CaptureOutput -AllowFailure
		if ($result.ExitCode -ne 0) {
			$failures.Add("${draftRelative}:`n$($result.Text)")
		} else {
			$result.Lines | ForEach-Object { Write-Host $_ }
		}
	}

	if ($failures.Count -gt 0) {
		Write-Host ''
		Write-Host 'No drafts were moved because these items need attention:' -ForegroundColor Red
		$failures | ForEach-Object { Write-Host $_ }
		throw 'Private draft precheck failed. Fix the listed files and run this phase again.'
	}
}

function Precheck-PublicDrafts {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$failures = New-Object System.Collections.Generic.List[string]
	foreach ($item in $Items) {
		$publicPath = Get-ItemPublicPath -Item $item
		$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
		Write-Host "Checking $publicRelative..."
		$result = Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot `
			-Arguments @('scripts/publish-content.mjs', $publicRelative, '--check') `
			-CaptureOutput -AllowFailure
		if ($result.ExitCode -ne 0) {
			$failures.Add("${publicRelative}:`n$($result.Text)")
		} else {
			$result.Lines | ForEach-Object { Write-Host $_ }
		}
	}
	if ($failures.Count -gt 0) {
		Write-Host ''
		Write-Host 'No drafts were changed because these items need attention:' -ForegroundColor Red
		$failures | ForEach-Object { Write-Host $_ }
		throw 'Public draft precheck failed. Fix the listed files and run this phase again.'
	}
}

function Promote-PrivateDrafts {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	if ($Items.Count -eq 0) {
		return $Session
	}

	foreach ($item in $Items) {
		$draftPath = Get-ItemDraftPath -Item $item
		$draftRelative = Get-RepositoryRelativePath -Path $draftPath -RepositoryRoot $RepositoryRoot
		$publicRelative = Get-PublicPathFromDraft -DraftPath $draftPath `
			-RepositoryRoot $RepositoryRoot
		Write-Host "Promoting $draftRelative..."
		try {
			Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot -Arguments @(
				'scripts/publish-content.mjs', $draftRelative, '--yes'
			) | Out-Null
			Set-WorkflowValue -InputObject $item -Name 'PublicPath' -Value $publicRelative
			Set-WorkflowValue -InputObject $item -Name 'Promoted' -Value $true
			Set-WorkflowValue -InputObject $item -Name 'PromotedAtUtc' -Value (
				[DateTime]::UtcNow.ToString('o')
			)
			$Session = Add-ExpectedWorkflowPath -Session $Session -Path $publicRelative
			Write-WorkflowSession -Session $Session
		} catch {
			Set-WorkflowValue -InputObject $Session -Name 'Status' -Value 'promotion-incomplete'
			Set-VerificationState -Session $Session -Status 'not-run' -Message (
				"Promotion stopped after a partial batch: $($_.Exception.Message)"
			)
			Write-WorkflowSession -Session $Session
			throw 'Draft promotion stopped. Completed items were recorded; the session can resume safely.'
		}
	}
	return $Session
}

function Promote-PublicDrafts {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	foreach ($item in $Items) {
		$publicPath = Get-ItemPublicPath -Item $item
		$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
		Write-Host "Publishing $publicRelative for local preview..."
		try {
			Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot -Arguments @(
				'scripts/publish-content.mjs', $publicRelative, '--yes'
			) | Out-Null
			Set-WorkflowValue -InputObject $item -Name 'Promoted' -Value $true
			Set-WorkflowValue -InputObject $item -Name 'PromotedAtUtc' -Value (
				[DateTime]::UtcNow.ToString('o')
			)
			$Session = Add-ExpectedWorkflowPath -Session $Session -Path $publicRelative
			Write-WorkflowSession -Session $Session
		} catch {
			Set-WorkflowValue -InputObject $Session -Name 'Status' -Value 'promotion-incomplete'
			Set-VerificationState -Session $Session -Status 'not-run' -Message (
				"Public draft promotion stopped after a partial batch: $($_.Exception.Message)"
			)
			Write-WorkflowSession -Session $Session
			throw 'Public draft promotion stopped. Completed items were recorded; the session can resume safely.'
		}
	}
	return $Session
}

function Assert-WorkflowItemsReady {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$failures = New-Object System.Collections.Generic.List[string]
	foreach ($item in $Items) {
		$title = [string](Get-WorkflowValue -InputObject $item -Names @('Title', 'Id'))
		$publicPath = Get-ItemPublicPath -Item $item
		if (-not $publicPath) {
			$failures.Add("${title}: no public file path is recorded.")
			continue
		}
		$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
		$publicAbsolute = Resolve-RepositoryPath -Path $publicPath -RepositoryRoot $RepositoryRoot
		if (-not (Test-Path -LiteralPath $publicAbsolute -PathType Leaf)) {
			$draftPath = Get-ItemDraftPath -Item $item
			$draftNote = if ($draftPath) { " The recorded draft is $draftPath." } else { '' }
			$failures.Add("${title}: expected public file is missing: $publicRelative.$draftNote")
			continue
		}
		if ([IO.Path]::GetExtension($publicAbsolute) -in @('.md', '.mdx')) {
			$draftState = Get-ContentDraftState -Path $publicPath -RepositoryRoot $RepositoryRoot
			if ($draftState -ne 'false') {
				$failures.Add("${title}: $publicRelative is not visibly published (draft state: $draftState).")
				continue
			}
		}
		Set-WorkflowValue -InputObject $item -Name 'Promoted' -Value $true
	}
	if ($failures.Count -gt 0) {
		throw "The batch is incomplete and cannot be marked ready:`n$($failures -join "`n")"
	}
	Write-WorkflowSession -Session $Session
}

function Start-PreviewServer {
	param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

	$status = Invoke-CheckedNative -FilePath 'npm.cmd' -WorkingDirectory $RepositoryRoot `
		-Arguments @('run', 'dev:status') -CaptureOutput -AllowFailure
	if ($status.ExitCode -eq 0) {
		Write-Host 'The Astro preview server is already running.'
		return
	}
	Write-Host 'Starting the Astro preview server in background mode...'
	Invoke-CheckedNative -FilePath 'npm.cmd' -WorkingDirectory $RepositoryRoot `
		-Arguments @('run', 'dev', '--', '--background') | Out-Null
}

function Open-PreviewRoutes {
	param(
		[Parameter(Mandatory = $true)][object[]]$Items,
		[switch]$DoNotOpen
	)

	$routes = @($Items | ForEach-Object { Get-ItemRoute -Item $_ } | Sort-Object -Unique)
	Write-Host ''
	Write-Host 'Preview routes:' -ForegroundColor Cyan
	foreach ($route in $routes) {
		$url = "http://localhost:4321$route"
		Write-Host "  $url"
		if (-not $DoNotOpen) {
			Start-Process $url
		}
	}
}

function Show-WorkingReview {
	param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

	Write-Host ''
	Write-Host 'Changed files:' -ForegroundColor Cyan
	Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $RepositoryRoot `
		-Arguments @('status', '--short') | Out-Null
	Write-Host ''
	Write-Host 'Change summary:' -ForegroundColor Cyan
	Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $RepositoryRoot `
		-Arguments @('diff', '--stat', '--') | Out-Null
	Write-Host ''
	Write-Host 'Text diff:' -ForegroundColor Cyan
	Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $RepositoryRoot `
		-Arguments @('diff', '--no-ext-diff', '--') | Out-Null
	$untracked = Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $RepositoryRoot `
		-Arguments @('ls-files', '--others', '--exclude-standard') -CaptureOutput
	foreach ($path in $untracked.Lines) {
		if (-not $path.Trim()) {
			continue
		}
		Write-Host ''
		Write-Host "New file diff: $path" -ForegroundColor Cyan
		Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $RepositoryRoot `
			-Arguments @('diff', '--no-index', '--no-ext-diff', '--', '/dev/null', $path) `
			-AllowFailure | Out-Null
	}
}

$repositoryRoot = Get-WorkflowRepositoryRoot
$session = Read-WorkflowSession
if ($null -eq $session) {
	throw 'There is no active authoring session. Start one with npm run content:workflow.'
}
$sessionStatus = [string](Get-WorkflowValue -InputObject $session -Names @('Status'))
if ($sessionStatus -in @('commit-pending', 'committed', 'pushed', 'deploying', 'published')) {
	throw "This batch is already '$sessionStatus'. Resume publication or deployment monitoring instead of reviewing it again."
}
$items = @(
	Get-WorkflowValue -InputObject $session -Names @('Items', 'BatchItems') |
		Where-Object { $null -ne $_ }
)
if ($items.Count -eq 0) {
	throw 'The active authoring session has no content items to review.'
}

$privateDraftItems = New-Object System.Collections.Generic.List[object]
$publicDraftItems = New-Object System.Collections.Generic.List[object]
$discoveryFailures = New-Object System.Collections.Generic.List[string]
foreach ($item in $items) {
	$title = [string](Get-WorkflowValue -InputObject $item -Names @('Title', 'Id'))
	$draftPath = Get-ItemDraftPath -Item $item
	$publicPath = Get-ItemPublicPath -Item $item
	if (-not $publicPath) {
		$discoveryFailures.Add("${title}: no public file path is recorded.")
		continue
	}
	if ($draftPath) {
		$draftAbsolute = Resolve-RepositoryPath -Path $draftPath -RepositoryRoot $repositoryRoot
		if (Test-Path -LiteralPath $draftAbsolute -PathType Leaf) {
			if (-not (Test-PrivateDraftItem -Item $item -RepositoryRoot $repositoryRoot)) {
				$discoveryFailures.Add("${title}: recorded draft is outside src/content/_drafts: $draftPath")
				continue
			}
			$privateDraftItems.Add($item)
			continue
		}
	}

	$publicAbsolute = Resolve-RepositoryPath -Path $publicPath -RepositoryRoot $repositoryRoot
	if (-not (Test-Path -LiteralPath $publicAbsolute -PathType Leaf)) {
		$draftNote = if ($draftPath) { " The recorded draft is also missing: $draftPath." } else { '' }
		$discoveryFailures.Add("${title}: expected public file is missing: $publicPath.$draftNote")
		continue
	}
	if ([IO.Path]::GetExtension($publicAbsolute) -in @('.md', '.mdx')) {
		$draftState = Get-ContentDraftState -Path $publicPath -RepositoryRoot $repositoryRoot
		if ($draftState -eq 'true') {
			$publicDraftItems.Add($item)
		} elseif ($draftState -ne 'false') {
			$discoveryFailures.Add("${title}: $publicPath has an invalid draft state: $draftState.")
		}
	}
}
if ($discoveryFailures.Count -gt 0) {
	throw "The batch contains missing or invalid content:`n$($discoveryFailures -join "`n")"
}
$privateDraftArray = [object[]]$privateDraftItems.ToArray()
$publicDraftArray = [object[]]$publicDraftItems.ToArray()

if ($privateDraftArray.Count -gt 0) {
	Write-Host 'Prechecking every private draft before moving any of them...' -ForegroundColor Cyan
	Precheck-PrivateDrafts -Items $privateDraftArray -RepositoryRoot $repositoryRoot
}
if ($publicDraftArray.Count -gt 0) {
	Write-Host 'Prechecking every public-collection draft before changing any of them...' -ForegroundColor Cyan
	Precheck-PublicDrafts -Items $publicDraftArray -RepositoryRoot $repositoryRoot
}
if ($privateDraftArray.Count + $publicDraftArray.Count -gt 0) {
	Write-Host ''
	Write-Host 'Every draft is ready.' -ForegroundColor Green
	Write-Host 'The next step makes them visible in the local preview and Git-visible in the working tree.'
	Write-Host 'It does not commit, push, or place anything on the live website.' -ForegroundColor Yellow
	if (-not $Yes) {
		$answer = Read-Host 'Promote all checked drafts for local preview? [Y/n]'
		if ($answer -and $answer -notmatch '^y(?:es)?$') {
			Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'editing'
			Write-WorkflowSession -Session $session
			Write-Host 'No drafts were changed. Continue editing, then run the workflow again.'
			return
		}
	}
	if ($privateDraftArray.Count -gt 0) {
		$session = Promote-PrivateDrafts -Items $privateDraftArray -Session $session `
			-RepositoryRoot $repositoryRoot
	}
	if ($publicDraftArray.Count -gt 0) {
		$session = Promote-PublicDrafts -Items $publicDraftArray -Session $session `
			-RepositoryRoot $repositoryRoot
	}
}

Assert-WorkflowItemsReady -Items $items -Session $session -RepositoryRoot $repositoryRoot

Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'previewing'
Write-WorkflowSession -Session $session
Start-PreviewServer -RepositoryRoot $repositoryRoot
Open-PreviewRoutes -Items $items -DoNotOpen:$SkipBrowser

if (-not $Yes) {
	Write-Host ''
	Write-Host 'Review every changed page at desktop and narrow browser widths.'
	Write-Host 'Choose E to leave this script and continue editing. Run the workflow again afterward.'
	$decision = Read-Host 'Enter E to return to editing, or V to run the full validation gate'
	if ($decision -notmatch '^v(?:alidate)?$') {
		Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'editing'
		Set-VerificationState -Session $session -Status 'not-run' -Message (
			'Preview opened; the author returned to editing.'
		)
		Write-WorkflowSession -Session $session
		Write-Host 'Session saved. Continue editing and return to the workflow when ready.'
		return
	}
}

Write-Host ''
Write-Host 'Running the complete repository verification gate...' -ForegroundColor Cyan
Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'validating'
Set-VerificationState -Session $session -Status 'running'
Write-WorkflowSession -Session $session
$verification = Invoke-CheckedNative -FilePath 'npm.cmd' -WorkingDirectory $repositoryRoot `
	-Arguments @('run', 'verify') -AllowFailure
if ($verification.ExitCode -ne 0) {
	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'editing'
	Set-VerificationState -Session $session -Status 'failed' -Message (
		'The complete npm run verify gate failed. Review the console output.'
	)
	Write-WorkflowSession -Session $session
	throw 'Validation failed. Fix the reported issues and run the review phase again.'
}

Show-WorkingReview -RepositoryRoot $repositoryRoot
$changedPaths = @(Get-WorkflowChangedPaths)
$expectedPaths = @(Get-ExpectedPaths -Session $session)
if ($changedPaths.Count -eq 0) {
	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'editing'
	Set-VerificationState -Session $session -Status 'failed' -Message 'No working changes were found.'
	Write-WorkflowSession -Session $session
	throw 'No website changes are present for this authoring session.'
}
try {
	Assert-NoUnexpectedWorkflowChanges -ExpectedPaths $expectedPaths
} catch {
	Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'editing'
	Set-VerificationState -Session $session -Status 'failed' -Message $_.Exception.Message
	Write-WorkflowSession -Session $session
	throw
}

$headCommit = (Invoke-CheckedNative -FilePath 'git' -WorkingDirectory $repositoryRoot `
	-Arguments @('rev-parse', 'HEAD') -CaptureOutput).Text
Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'ready-to-publish'
Set-WorkflowValue -InputObject $session -Name 'Verification' -Value ([pscustomobject]@{
	Status = 'passed'
	VerifiedAtUtc = [DateTime]::UtcNow.ToString('o')
	HeadCommit = $headCommit
})
Write-WorkflowSession -Session $session

Write-Host ''
Write-Host 'The batch passed validation and contains only recorded changes.' -ForegroundColor Green
Write-Host 'Run the workflow again and choose Publish when you are ready for the final review.'
