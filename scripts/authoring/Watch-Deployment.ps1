#requires -Version 5.1

[CmdletBinding()]
param(
	[ValidatePattern('^[0-9a-fA-F]{40}$')]
	[string]$CommitSha,

	[switch]$DoNotOpenLivePages
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
		$detail = ($outputLines -join [Environment]::NewLine).Trim()
		throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$detail"
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

function Get-SessionRoutes {
	param(
		[AllowNull()]
		[object]$Session
	)

	if ($null -eq $Session) {
		return @()
	}
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

function Find-DeploymentRun {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Sha
	)

	$attempts = 30
	for ($attempt = 1; $attempt -le $attempts; $attempt++) {
		$result = Invoke-CheckedNative -FilePath 'gh' -Arguments @(
			'run', 'list',
			'--workflow', 'pages.yml',
			'--event', 'push',
			'--commit', $Sha,
			'--limit', '20',
			'--json', 'databaseId,headSha,status,conclusion,url,workflowName,createdAt'
		) -CaptureOutput
		$parsedRuns = if ($result.Text) { $result.Text | ConvertFrom-Json } else { @() }
		$runs = @($parsedRuns | Where-Object { $null -ne $_ })
		$run = @(
			$runs | Where-Object {
				$headSha = Get-WorkflowValue -InputObject $_ -Names @('headSha')
				$workflowName = Get-WorkflowValue -InputObject $_ -Names @('workflowName')
				$headSha -eq $Sha -and $workflowName -eq 'Validate and deploy Pages'
			} | Sort-Object createdAt -Descending
		) | Select-Object -First 1
		if ($null -ne $run) {
			return $run
		}

		if ($attempt -lt $attempts) {
			Write-Host "Waiting for GitHub Actions to register the pushed commit ($attempt/$attempts)..."
			Start-Sleep -Seconds 5
		}
	}

	throw "No 'Validate and deploy Pages' push run appeared for commit $Sha. The active session was retained for recovery."
}

function Test-LiveUrls {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Urls
	)

	$pending = New-Object System.Collections.Generic.List[string]
	$Urls | Sort-Object -Unique | ForEach-Object { $pending.Add($_) }
	$attempts = 12

	for ($attempt = 1; $attempt -le $attempts -and $pending.Count -gt 0; $attempt++) {
		$failedThisAttempt = New-Object System.Collections.Generic.List[string]
		foreach ($url in @($pending)) {
			try {
				$response = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 5 -TimeoutSec 30 -Headers @{
					'Cache-Control' = 'no-cache'
					'User-Agent' = 'bellsworth-authoring-workflow'
				}
				if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
					throw "HTTP $($response.StatusCode)"
				}
				Write-Host "Live: $url" -ForegroundColor Green
			} catch {
				Write-Warning "Attempt $attempt/$attempts failed for $url ($($_.Exception.Message))"
				$failedThisAttempt.Add($url)
			}
		}

		$pending = $failedThisAttempt
		if ($pending.Count -gt 0 -and $attempt -lt $attempts) {
			Start-Sleep -Seconds 5
		}
	}

	if ($pending.Count -gt 0) {
		throw "Live verification failed after $attempts attempts for:`n$($pending -join "`n")"
	}
}

$repositoryRoot = Get-WorkflowRepositoryRoot
Push-Location $repositoryRoot
try {
	$session = $null
	try {
		$session = Read-WorkflowSession -RepositoryRoot $repositoryRoot
	} catch {
		if (-not $CommitSha) {
			throw
		}
		Write-Warning 'No active authoring session was found. Only the standard live endpoints will be checked.'
	}

	$sessionCommitSha = if ($null -ne $session) {
		[string](Get-WorkflowValue -InputObject $session -Names @('CommitSha', 'PublishedCommitSha'))
	} else {
		''
	}
	if (-not $CommitSha) {
		$CommitSha = $sessionCommitSha
	}
	if (-not $CommitSha -or $CommitSha -notmatch '^[0-9a-fA-F]{40}$') {
		throw 'Provide the full 40-character commit SHA, or resume a session that records one.'
	}
	$CommitSha = $CommitSha.ToLowerInvariant()
	$sessionMatchesCommit = $null -ne $session -and $sessionCommitSha -eq $CommitSha
	if ($null -ne $session -and -not $sessionMatchesCommit) {
		Write-Warning "The active session belongs to commit '$sessionCommitSha', so it will not be modified or archived while watching $CommitSha."
	}

	Assert-WorkflowCanonicalOrigin -RepositoryRoot $repositoryRoot | Out-Null
	Invoke-CheckedNative -FilePath 'gh' -Arguments @('auth', 'status') | Out-Null
	Write-Host "Finding the deployment run for $CommitSha..."
	$run = Find-DeploymentRun -Sha $CommitSha
	$runId = [string]$run.databaseId
	Write-Host "Watching GitHub Actions run ${runId}: $($run.url)"

	if ($sessionMatchesCommit) {
		Set-WorkflowValue -InputObject $session -Name 'ActionsRunId' -Value $runId
		Set-WorkflowValue -InputObject $session -Name 'ActionsRunUrl' -Value ([string]$run.url)
		Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'deploying'
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session
	}

	$watchResult = Invoke-CheckedNative -FilePath 'gh' -Arguments @(
		'run', 'watch', $runId, '--exit-status'
	) -AllowFailure
	if ($watchResult.ExitCode -ne 0) {
		Write-Host ''
		Write-Host 'Failed GitHub Actions log:' -ForegroundColor Red
		Invoke-CheckedNative -FilePath 'gh' -Arguments @('run', 'view', $runId, '--log-failed') -AllowFailure | Out-Null
		throw "GitHub Actions run $runId failed. The active session was retained for recovery."
	}

	$runDetailResult = Invoke-CheckedNative -FilePath 'gh' -Arguments @(
		'run', 'view', $runId, '--json', 'conclusion,status,url,headSha,workflowName'
	) -CaptureOutput
	$runDetail = $runDetailResult.Text | ConvertFrom-Json
	if ($runDetail.headSha -ne $CommitSha -or $runDetail.workflowName -ne 'Validate and deploy Pages') {
		throw 'The completed GitHub Actions run does not match the requested commit and workflow.'
	}
	if ($runDetail.status -ne 'completed' -or $runDetail.conclusion -ne 'success') {
		throw "GitHub Actions ended with status '$($runDetail.status)' and conclusion '$($runDetail.conclusion)'."
	}

	$baseUrl = 'https://bellsworth.dev'
	$standardRoutes = @('/', '/robots.txt', '/rss.xml', '/sitemap-index.xml')
	$contentRoutes = if ($sessionMatchesCommit) { @(Get-SessionRoutes -Session $session) } else { @() }
	$allUrls = @(
		@($standardRoutes) + @($contentRoutes) |
			ForEach-Object { "$baseUrl$_" } |
			Sort-Object -Unique
	)

	Write-Host ''
	Write-Host 'GitHub Pages deployed successfully. Checking the live website...'
	[Net.ServicePointManager]::SecurityProtocol =
		[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
	Test-LiveUrls -Urls $allUrls

	if (-not $DoNotOpenLivePages) {
		$urlsToOpen = if ($contentRoutes.Count -gt 0) {
			@($contentRoutes | ForEach-Object { "$baseUrl$_" } | Sort-Object -Unique)
		} else {
			@("$baseUrl/")
		}
		foreach ($url in $urlsToOpen) {
			try {
				Start-Process $url
			} catch {
				Write-Warning "The live page passed its check but could not be opened automatically: $url"
			}
		}
	}

	if ($sessionMatchesCommit) {
		Set-WorkflowValue -InputObject $session -Name 'Status' -Value 'published'
		Set-WorkflowValue -InputObject $session -Name 'PublishedAtUtc' -Value ([DateTime]::UtcNow.ToString('o'))
		Set-WorkflowValue -InputObject $session -Name 'LiveUrls' -Value $allUrls
		Write-WorkflowSession -RepositoryRoot $repositoryRoot -Session $session

		$stateDirectory = Join-Path $repositoryRoot '.authoring-workflow'
		$activeSessionPath = Join-Path $stateDirectory 'session.json'
		$archiveDirectory = Join-Path $stateDirectory 'archive'
		if (-not (Test-Path -LiteralPath $archiveDirectory -PathType Container)) {
			New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
		}
		$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
		$archivePath = Join-Path $archiveDirectory "$timestamp-$($CommitSha.Substring(0, 12)).json"
		if (Test-Path -LiteralPath $archivePath) {
			$archivePath = Join-Path $archiveDirectory "$timestamp-$($CommitSha.Substring(0, 12))-$([Guid]::NewGuid().ToString('N').Substring(0, 8)).json"
		}
		if (-not (Test-Path -LiteralPath $activeSessionPath -PathType Leaf)) {
			throw "Live checks passed, but the active session file could not be found for archiving: $activeSessionPath"
		}
		Move-Item -LiteralPath $activeSessionPath -Destination $archivePath
		Write-Host "Archived the completed authoring session: $archivePath"
	}

	Write-Host ''
	Write-Host "Published successfully: $CommitSha" -ForegroundColor Green
} finally {
	Pop-Location
}
