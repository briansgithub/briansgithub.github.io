#requires -Version 5.1

[CmdletBinding()]
param(
	[ValidateSet('BodyImage', 'ProjectCover', 'PrintModel', 'ResumePdf')]
	[string]$Type,

	[string]$ItemId,

	[string]$SourcePath,

	[string]$AltText,

	[string]$Name
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
		[string]$WorkingDirectory
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
	$outputLines | ForEach-Object { Write-Host $_ }
	if ($exitCode -ne 0) {
		throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')"
	}

	return [pscustomobject]@{
		ExitCode = $exitCode
		Lines = $outputLines
		Text = ($outputLines -join [Environment]::NewLine).Trim()
	}
}

function ConvertTo-Slug {
	param([Parameter(Mandatory = $true)][string]$Value)

	$normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
	$builder = New-Object Text.StringBuilder
	foreach ($character in $normalized.ToCharArray()) {
		$category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
		if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
			[void]$builder.Append($character)
		}
	}
	$slug = $builder.ToString().ToLowerInvariant()
	$slug = $slug -replace '&', ' and '
	$slug = $slug -replace '[^a-z0-9]+', '-'
	return $slug.Trim('-') -replace '-{2,}', '-'
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

function Select-WorkflowFile {
	param(
		[Parameter(Mandatory = $true)][string]$Title,
		[Parameter(Mandatory = $true)][string]$Filter,
		[string]$SuppliedPath
	)

	if ($SuppliedPath) {
		$candidate = $SuppliedPath.Trim().Trim('"')
	} else {
		$candidate = $null
		try {
			Add-Type -AssemblyName System.Windows.Forms
			$dialog = New-Object System.Windows.Forms.OpenFileDialog
			$dialog.Title = $Title
			$dialog.Filter = $Filter
			$dialog.CheckFileExists = $true
			$dialog.Multiselect = $false
			if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$candidate = $dialog.FileName
			}
		} catch {
			Write-Warning "The Windows file picker was unavailable: $($_.Exception.Message)"
		}

		if (-not $candidate) {
			Write-Host 'Paste the full path instead, or press Enter to cancel.'
			$candidate = (Read-Host $Title).Trim().Trim('"')
		}
	}

	if (-not $candidate) {
		throw 'No file was selected. Nothing was changed.'
	}
	$resolved = [IO.Path]::GetFullPath($candidate)
	if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
		throw "The selected file does not exist: $resolved"
	}
	return $resolved
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

function Get-ItemPublicPath {
	param([Parameter(Mandatory = $true)][object]$Item)

	return [string](Get-WorkflowValue -InputObject $Item -Names @(
		'PublicPath', 'DestinationPath', 'PublishedPath', 'TargetPath'
	))
}

function Get-ItemWorkingPath {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$draftPath = [string](Get-WorkflowValue -InputObject $Item -Names @(
		'DraftPath', 'SourcePath', 'WorkingPath'
	))
	if ($draftPath) {
		$draftAbsolute = Resolve-RepositoryPath -Path $draftPath -RepositoryRoot $RepositoryRoot
		if (Test-Path -LiteralPath $draftAbsolute -PathType Leaf) {
			return $draftAbsolute
		}
	}

	$publicPath = Get-ItemPublicPath -Item $Item
	if (-not $publicPath) {
		throw 'The selected item does not record a future public content path.'
	}
	return Resolve-RepositoryPath -Path $publicPath -RepositoryRoot $RepositoryRoot
}

function Get-EligibleItems {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$AssetType
	)

	$items = @(
		Get-WorkflowValue -InputObject $Session -Names @('Items', 'BatchItems') |
			Where-Object { $null -ne $_ }
	)
	return @($items | Where-Object {
			$item = $_
			$kind = Get-NormalizedItemKind -Item $item
			$eligible = $false
			switch ($AssetType) {
				'BodyImage' {
					$publicPath = Get-ItemPublicPath -Item $item
					$eligible = $publicPath -match '\.mdx?$' -and $kind -in @(
						'writing', 'projects', 'prints', 'books', 'about'
					)
					break
				}
				'ProjectCover' { $eligible = $kind -eq 'projects'; break }
				'PrintModel' { $eligible = $kind -eq 'prints'; break }
				'ResumePdf' { $eligible = $kind -eq 'resume'; break }
			}
			$eligible
		})
}

function Select-WorkflowItem {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$AssetType,
		[string]$RequestedId
	)

	$items = @(Get-EligibleItems -Session $Session -AssetType $AssetType)
	if ($items.Count -eq 0) {
		throw "The active batch has no item that accepts a $AssetType asset. Add the item first."
	}
	if ($RequestedId) {
		$match = @($items | Where-Object {
				[string](Get-WorkflowValue -InputObject $_ -Names @('Id', 'ItemId')) -eq $RequestedId
			})
		if ($match.Count -ne 1) {
			throw "No eligible batch item has ID '$RequestedId'."
		}
		return $match[0]
	}
	if ($items.Count -eq 1) {
		return $items[0]
	}

	Write-Host ''
	Write-Host 'Choose the content item for this asset:' -ForegroundColor Cyan
	for ($index = 0; $index -lt $items.Count; $index += 1) {
		$title = [string](Get-WorkflowValue -InputObject $items[$index] -Names @(
			'Title', 'Label', 'Slug'
		))
		$kind = Get-NormalizedItemKind -Item $items[$index]
		Write-Host "  $($index + 1). [$kind] $title"
	}
	$selection = Read-Host "Selection (1-$($items.Count))"
	$number = 0
	if (-not [int]::TryParse($selection, [ref]$number) -or $number -lt 1 -or
		$number -gt $items.Count) {
		throw 'The item selection was not valid. Nothing was changed.'
	}
	return $items[$number - 1]
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

function Add-SessionAsset {
	param(
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$Kind,
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][string]$SourceName,
		[hashtable]$Details
	)

	$asset = [ordered]@{
		Id = [Guid]::NewGuid().ToString('N')
		Kind = $Kind
		Path = $Path.Replace('\', '/')
		ContentItemId = [string](Get-WorkflowValue -InputObject $Item -Names @('Id', 'ItemId'))
		SourceName = $SourceName
		AddedAtUtc = [DateTime]::UtcNow.ToString('o')
	}
	if ($null -ne $Details) {
		foreach ($key in $Details.Keys) {
			$asset[$key] = $Details[$key]
		}
	}

	$assets = @(
		Get-WorkflowValue -InputObject $Session -Names @('Assets') |
			Where-Object { $null -ne $_ }
	)
	Set-WorkflowValue -InputObject $Session -Name 'Assets' -Value @($assets + [pscustomobject]$asset)
	Set-WorkflowValue -InputObject $Session -Name 'Status' -Value 'editing'
	Set-WorkflowValue -InputObject $Session -Name 'Verification' -Value ([pscustomobject]@{
		Status = 'not-run'
		Message = 'An asset changed after the previous review.'
	})
	return $Session
}

function Start-AssetMutation {
	param([Parameter(Mandatory = $true)][object]$Session)

	Set-WorkflowValue -InputObject $Session -Name 'Status' -Value 'editing'
	Set-WorkflowValue -InputObject $Session -Name 'Verification' -Value ([pscustomobject]@{
		Status = 'not-run'
		Message = 'An asset update began; review and validation are required again.'
	})
	Write-WorkflowSession -Session $Session
}

function Set-ClipboardText {
	param([Parameter(Mandatory = $true)][string]$Text)

	try {
		$clipboardCommand = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
		if ($null -ne $clipboardCommand) {
			Set-Clipboard -Value $Text
			return $true
		}
		Add-Type -AssemblyName System.Windows.Forms
		[System.Windows.Forms.Clipboard]::SetText($Text)
		return $true
	} catch {
		Write-Warning "The snippet could not be copied to the clipboard: $($_.Exception.Message)"
		return $false
	}
}

function Get-ImportedMediaResult {
	param([Parameter(Mandatory = $true)][object]$CommandResult)

	$createdLine = @($CommandResult.Lines | Where-Object { $_ -match '^Created:\s+' }) |
		Select-Object -Last 1
	$snippetMarker = -1
	for ($index = 0; $index -lt $CommandResult.Lines.Count; $index += 1) {
		if ($CommandResult.Lines[$index] -eq 'Markdown snippet:') {
			$snippetMarker = $index
		}
	}
	if (-not $createdLine -or $snippetMarker -lt 0 -or
		$snippetMarker + 1 -ge $CommandResult.Lines.Count) {
		throw 'The media importer succeeded but its result could not be interpreted.'
	}
	return [pscustomobject]@{
		Path = ($createdLine -replace '^Created:\s+', '').Replace('\', '/')
		Snippet = $CommandResult.Lines[$snippetMarker + 1]
	}
}

function Set-FrontmatterObject {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$FieldName,
		[Parameter(Mandatory = $true)][string[]]$Lines
	)

	$content = [IO.File]::ReadAllText($Path)
	$frontmatter = [regex]::Match(
		$content,
		'\A---\r?\n(?<yaml>[\s\S]*?)\r?\n---(?<ending>\r?\n|$)'
	)
	if (-not $frontmatter.Success) {
		throw "The content file does not begin with YAML frontmatter: $Path"
	}

	$newLine = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
	$yaml = $frontmatter.Groups['yaml'].Value
	$block = $Lines -join $newLine
	$fieldPattern = '(?m)^' + [regex]::Escape($FieldName) +
		':[^\r\n]*(?:\r?\n[ \t]+[^\r\n]*)*'
	$fieldRegex = New-Object Text.RegularExpressions.Regex($fieldPattern)
	if ($fieldRegex.IsMatch($yaml)) {
		$updatedYaml = $fieldRegex.Replace(
			$yaml,
			[Text.RegularExpressions.MatchEvaluator]{ param($match) $block },
			1
		)
	} elseif ([regex]::IsMatch($yaml, '(?m)^draft:')) {
		$draftRegex = New-Object Text.RegularExpressions.Regex('(?m)^draft:')
		$updatedYaml = $draftRegex.Replace(
			$yaml,
			[Text.RegularExpressions.MatchEvaluator]{
				param($match)
				"$block$newLine$($match.Value)"
			},
			1
		)
	} else {
		$updatedYaml = "$yaml$newLine$block"
	}

	$updatedFrontmatter = "---$newLine$updatedYaml$newLine---" +
		$frontmatter.Groups['ending'].Value
	$updatedContent = $updatedFrontmatter + $content.Substring($frontmatter.Length)
	Write-WorkflowTextAtomic -Path $Path -Content $updatedContent
}

function Copy-FileAtomically {
	param(
		[Parameter(Mandatory = $true)][string]$Source,
		[Parameter(Mandatory = $true)][string]$Destination
	)

	$directory = Split-Path -Parent $Destination
	if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
		[void](New-Item -ItemType Directory -Path $directory -Force)
	}
	$temporary = "$Destination.tmp-$([Guid]::NewGuid().ToString('N'))"
	try {
		[IO.File]::Copy($Source, $temporary, $false)
		if (Test-Path -LiteralPath $Destination -PathType Leaf) {
			[IO.File]::Replace($temporary, $Destination, $null)
		} else {
			[IO.File]::Move($temporary, $Destination)
		}
	} finally {
		if (Test-Path -LiteralPath $temporary -PathType Leaf) {
			Remove-Item -LiteralPath $temporary -Force
		}
	}
}

function Confirm-Replacement {
	param([Parameter(Mandatory = $true)][string]$Path)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		return
	}
	$answer = Read-Host "A file already exists at $Path. Replace it? [y/N]"
	if ($answer -notmatch '^y(?:es)?$') {
		throw 'Replacement was cancelled. Nothing was changed.'
	}
}

function Request-AltText {
	param([string]$SuppliedAltText)

	$value = $SuppliedAltText
	if (-not $value) {
		$value = Read-Host 'Describe the useful visual content for visitors using a screen reader'
	}
	$value = $value.Trim()
	if ($value.Length -lt 3 -or $value.Length -gt 240 -or
		$value -match '^(image|photo|picture|thumbnail)$') {
		throw 'Alternative text must be a meaningful description from 3 through 240 characters.'
	}
	return $value
}

function Add-BodyImage {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$source = Select-WorkflowFile -Title 'Choose the body image' -Filter (
		'Image files|*.jpg;*.jpeg;*.png;*.webp;*.avif;*.gif;*.tif;*.tiff;*.heic|' +
		'All files|*.*'
	) -SuppliedPath $SourcePath
	$alt = Request-AltText -SuppliedAltText $AltText
	$publicPath = Get-ItemPublicPath -Item $Item
	if (-not $publicPath -or $publicPath -notmatch '\.mdx?$') {
		throw 'Body images require a future public Markdown or MDX path.'
	}
	$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
	$slug = ConvertTo-Slug -Value ([IO.Path]::GetFileNameWithoutExtension($publicRelative))
	$outputName = if ($Name) { $Name } else { ConvertTo-Slug -Value ([IO.Path]::GetFileNameWithoutExtension($source)) }
	if (-not $outputName -or $outputName -ne (ConvertTo-Slug -Value $outputName)) {
		throw 'The image name must be lowercase kebab-case.'
	}

	Start-AssetMutation -Session $Session
	$result = Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot -Arguments @(
		'scripts/import-media.mjs', $source, '--alt', $alt, '--name', $outputName,
		'--subdir', $slug, '--content', $publicRelative
	)
	$media = Get-ImportedMediaResult -CommandResult $result
	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $media.Path
	$Session = Add-SessionAsset -Session $Session -Kind 'body-image' -Path $media.Path -Item $Item `
		-SourceName ([IO.Path]::GetFileName($source)) -Details @{ AltText = $alt }
	Write-WorkflowSession -Session $Session

	Write-Host ''
	Write-Host 'Paste this line into the Markdown body:' -ForegroundColor Green
	Write-Host $media.Snippet
	if (Set-ClipboardText -Text $media.Snippet) {
		Write-Host 'The Markdown image line is also on the clipboard.'
	}
}

function Add-ProjectCover {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$source = Select-WorkflowFile -Title 'Choose the project cover image' -Filter (
		'Image files|*.jpg;*.jpeg;*.png;*.webp;*.avif;*.gif;*.tif;*.tiff;*.heic|' +
		'All files|*.*'
	) -SuppliedPath $SourcePath
	$alt = Request-AltText -SuppliedAltText $AltText
	$publicPath = Get-ItemPublicPath -Item $Item
	$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
	$slug = ConvertTo-Slug -Value ([IO.Path]::GetFileNameWithoutExtension($publicRelative))
	$canonicalRelative = "src/assets/images/$slug/cover.webp"
	$canonicalPath = Resolve-RepositoryPath -Path $canonicalRelative -RepositoryRoot $RepositoryRoot
	$temporaryName = "cover-update-$([Guid]::NewGuid().ToString('N'))"
	if (Test-Path -LiteralPath $canonicalPath -PathType Leaf) {
		Confirm-Replacement -Path $canonicalPath
	}
	Start-AssetMutation -Session $Session
	$result = Invoke-CheckedNative -FilePath 'node' -WorkingDirectory $RepositoryRoot -Arguments @(
		'scripts/import-media.mjs', $source, '--alt', $alt, '--name', $temporaryName,
		'--subdir', $slug, '--content', $publicRelative
	)
	$media = Get-ImportedMediaResult -CommandResult $result
	$temporaryPath = Resolve-RepositoryPath -Path $media.Path -RepositoryRoot $RepositoryRoot
	try {
		if (Test-Path -LiteralPath $canonicalPath -PathType Leaf) {
			[IO.File]::Replace($temporaryPath, $canonicalPath, $null)
		} else {
			[IO.File]::Move($temporaryPath, $canonicalPath)
		}
	} finally {
		if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
			Remove-Item -LiteralPath $temporaryPath -Force
		}
	}
	$coverPath = '../../assets/images/' + $slug + '/cover.webp'
	$escapedAlt = $alt.Replace("'", "''")
	$workingPath = Get-ItemWorkingPath -Item $Item -RepositoryRoot $RepositoryRoot
	Set-FrontmatterObject -Path $workingPath -FieldName 'cover' -Lines @(
		'cover:',
		"  image: $coverPath",
		"  alt: '$escapedAlt'"
	)

	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $canonicalRelative
	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $publicRelative
	$Session = Add-SessionAsset -Session $Session -Kind 'project-cover' -Path $canonicalRelative -Item $Item `
		-SourceName ([IO.Path]::GetFileName($source)) -Details @{ AltText = $alt }
	Write-WorkflowSession -Session $Session
	Write-Host "Project cover metadata updated in $workingPath" -ForegroundColor Green
}

function Add-PrintModel {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$source = Select-WorkflowFile -Title 'Choose the STL model' -Filter 'STL models|*.stl' `
		-SuppliedPath $SourcePath
	if ([IO.Path]::GetExtension($source) -ine '.stl') {
		throw 'Only an .stl model can be added to a 3D Print entry.'
	}
	$fileInfo = Get-Item -LiteralPath $source
	$maximumBytes = 5 * 1024 * 1024
	if ($fileInfo.Length -le 0 -or $fileInfo.Length -gt $maximumBytes) {
		throw "The STL must be non-empty and no larger than 5 MiB. Selected size: $($fileInfo.Length) bytes."
	}

	$publicPath = Get-ItemPublicPath -Item $Item
	$publicRelative = Get-RepositoryRelativePath -Path $publicPath -RepositoryRoot $RepositoryRoot
	$slug = ConvertTo-Slug -Value ([IO.Path]::GetFileNameWithoutExtension($publicRelative))
	$destinationRelative = "public/files/prints/$slug.stl"
	$destination = Resolve-RepositoryPath -Path $destinationRelative -RepositoryRoot $RepositoryRoot
	Confirm-Replacement -Path $destination
	Start-AssetMutation -Session $Session
	Copy-FileAtomically -Source $source -Destination $destination

	$workingPath = Get-ItemWorkingPath -Item $Item -RepositoryRoot $RepositoryRoot
	Set-FrontmatterObject -Path $workingPath -FieldName 'model' -Lines @(
		'model:',
		"  file: /files/prints/$slug.stl",
		"  sizeBytes: $($fileInfo.Length)"
	)
	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $destinationRelative
	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $publicRelative
	$Session = Add-SessionAsset -Session $Session -Kind 'print-model' -Path $destinationRelative `
		-Item $Item -SourceName $fileInfo.Name -Details @{ SizeBytes = $fileInfo.Length }
	Write-WorkflowSession -Session $Session
	Write-Host "STL copied and model metadata updated ($($fileInfo.Length) bytes)." -ForegroundColor Green
}

function Add-ResumePdf {
	param(
		[Parameter(Mandatory = $true)][object]$Item,
		[Parameter(Mandatory = $true)][object]$Session,
		[Parameter(Mandatory = $true)][string]$RepositoryRoot
	)

	$source = Select-WorkflowFile -Title 'Choose the finished resume PDF' -Filter 'PDF documents|*.pdf' `
		-SuppliedPath $SourcePath
	if ([IO.Path]::GetExtension($source) -ine '.pdf') {
		throw 'The selected resume must be a PDF.'
	}
	$fileInfo = Get-Item -LiteralPath $source
	$maximumBytes = 3 * 1024 * 1024
	if ($fileInfo.Length -le 4 -or $fileInfo.Length -gt $maximumBytes) {
		throw "The PDF must be valid and no larger than 3 MiB. Selected size: $($fileInfo.Length) bytes."
	}
	$stream = [IO.File]::OpenRead($source)
	try {
		$signatureBytes = New-Object byte[] 5
		[void]$stream.Read($signatureBytes, 0, 5)
	} finally {
		$stream.Dispose()
	}
	$signature = [Text.Encoding]::ASCII.GetString($signatureBytes)
	if ($signature -ne '%PDF-') {
		throw 'The selected file does not have a valid PDF signature.'
	}

	$destinationRelative = 'public/files/brian-ellsworth-resume.pdf'
	$destination = Resolve-RepositoryPath -Path $destinationRelative -RepositoryRoot $RepositoryRoot
	if (Test-Path -LiteralPath $destination -PathType Leaf) {
		$backupDirectory = Join-Path $RepositoryRoot '.authoring-workflow/backups'
		[void](New-Item -ItemType Directory -Path $backupDirectory -Force)
		$timestamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
		$backupId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
		$backupName = "$timestamp-$backupId-brian-ellsworth-resume.pdf"
		$backupPath = Join-Path $backupDirectory $backupName
		[IO.File]::Copy($destination, $backupPath, $false)
		$backupRelative = Get-RepositoryRelativePath -Path $backupPath -RepositoryRoot $RepositoryRoot
		Write-Host "Backup saved in the ignored workflow directory: $backupRelative"
	} else {
		$backupRelative = $null
	}
	Start-AssetMutation -Session $Session
	Copy-FileAtomically -Source $source -Destination $destination

	$details = @{ SizeBytes = $fileInfo.Length }
	if ($backupRelative) {
		$details.BackupPath = $backupRelative
	}
	$Session = Add-ExpectedWorkflowPath -Session $Session -Path $destinationRelative
	$Session = Add-SessionAsset -Session $Session -Kind 'resume-pdf' -Path $destinationRelative `
		-Item $Item -SourceName $fileInfo.Name -Details $details
	Write-WorkflowSession -Session $Session
	Write-Host "Resume PDF replaced safely ($($fileInfo.Length) bytes)." -ForegroundColor Green
}

$repositoryRoot = Get-WorkflowRepositoryRoot
$session = Read-WorkflowSession
if ($null -eq $session) {
	throw 'There is no active authoring session. Start one with npm run content:workflow.'
}
$sessionStatus = [string](Get-WorkflowValue -InputObject $session -Names @('Status'))
if ($sessionStatus -in @('commit-pending', 'committed', 'pushed', 'deploying', 'published')) {
	throw "This batch is already '$sessionStatus'. Assets can be changed only before the batch is committed."
}

if (-not $Type) {
	Write-Host ''
	Write-Host 'Add a prepared website asset' -ForegroundColor Cyan
	Write-Host '  1. Body image (creates safe WebP and copies Markdown to the clipboard)'
	Write-Host '  2. Project cover (creates safe WebP and updates frontmatter)'
	Write-Host '  3. 3D Print STL model (copies the model and updates frontmatter)'
	Write-Host '  4. Resume PDF (validates, backs up, and replaces the download)'
	$choice = Read-Host 'Selection (1-4)'
	$Type = switch ($choice) {
		'1' { 'BodyImage' }
		'2' { 'ProjectCover' }
		'3' { 'PrintModel' }
		'4' { 'ResumePdf' }
		default { throw 'The asset selection was not valid. Nothing was changed.' }
	}
}

$item = Select-WorkflowItem -Session $session -AssetType $Type -RequestedId $ItemId
switch ($Type) {
	'BodyImage' {
		Add-BodyImage -Item $item -Session $session -RepositoryRoot $repositoryRoot
	}
	'ProjectCover' {
		Add-ProjectCover -Item $item -Session $session -RepositoryRoot $repositoryRoot
	}
	'PrintModel' {
		Add-PrintModel -Item $item -Session $session -RepositoryRoot $repositoryRoot
	}
	'ResumePdf' {
		Add-ResumePdf -Item $item -Session $session -RepositoryRoot $repositoryRoot
	}
}

Write-Host ''
Write-Host 'Asset step complete. Run the workflow again to add another asset or review the batch.'
