# Configuration
$sizeThresholdMB = 2
$gitattributesPath = ".gitattributes"
$lfsPattern = "filter=lfs diff=lfs merge=lfs -text"

# Check if we're inside a Git repo
if (-not (Test-Path ".git")) {
    Write-Host "The current directory is not a Git repository."
    exit 1
}

# Get all files larger than the threshold
$largeFiles = Get-ChildItem -Recurse -File | Where-Object {
    $_.Length -ge ($sizeThresholdMB * 1MB)
}

if (-not $largeFiles) {
    Write-Host "No files larger than $sizeThresholdMB MB were found."
    exit
}

# Load existing .gitattributes content, if any
if (Test-Path $gitattributesPath) {
    $existingGitattributes = Get-Content $gitattributesPath
} else {
    $existingGitattributes = @()
}

$addedFiles = @()

foreach ($file in $largeFiles) {
    $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1).Replace("\", "/")
    $quotedPath = "`"$relativePath`""  # Always quote the path

    # Check if the file is ignored by .gitignore
    $isIgnored = git check-ignore "$relativePath" 2>$null
    if ($isIgnored) {
        Write-Host "Ignored by .gitignore: $relativePath"
        continue
    }

    # Check if already tracked
    $alreadyTracked = $existingGitattributes | Where-Object { $_ -like "*$relativePath*" }
    if (-not $alreadyTracked) {
        "$quotedPath $lfsPattern" | Add-Content $gitattributesPath
        $addedFiles += $relativePath
        Write-Host "Added to .gitattributes: $quotedPath"
    }
}

if ($addedFiles.Count -eq 0) {
    Write-Host "No new files were added to .gitattributes."
} else {
    Write-Host "`nThe following files were added to Git LFS tracking:"
    $addedFiles | ForEach-Object { Write-Host $_ }
}
