<#
.SYNOPSIS
  Publish the fork release (commit + tag + GitHub Release + asset) through the GitHub REST API.
  No git installation is required.

.DESCRIPTION
  Reads a fine-grained PAT from a file (never from the command line), then:
    1. verifies the token account and the target fork;
    2. creates blobs for every changed file on top of the fork's current default-branch head;
    3. creates one commit, fast-forwards the branch;
    4. creates an annotated tag;
    5. creates a pre-release with the bilingual notes and uploads the tarball.

  Safe defaults: refuses to run if the tag or release already exists; -DryRun prints the plan only.

.EXAMPLE
  .\scripts\publish-fork-release.ps1 -TokenFile E:\DeepSeekRuntime\APP\.gh-token -DryRun
  .\scripts\publish-fork-release.ps1 -TokenFile E:\DeepSeekRuntime\APP\.gh-token
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$TokenFile,
  [string]$Owner = 'Hanice404',
  [string]$Repo = 'dsh-chat-manager',
  [string]$Tag = 'v2.0.0-alpha.2',
  [string]$Version = '2.0.0-alpha.2',
  [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$AssetPath = '',
  [string]$NotesPath = '',
  [string]$CommitMessage = '',
  [switch]$AllowDifferentAccount,
  [switch]$SkipAsset,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message) { throw "publish-fork-release: $Message" }
function Info([string]$Message) { Write-Host "==> $Message" }

# ---------- inputs ----------
$TokenFile = [System.IO.Path]::GetFullPath($TokenFile)
if (-not (Test-Path -LiteralPath $TokenFile)) { Fail "token file not found: $TokenFile" }
$token = (Get-Content -LiteralPath $TokenFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { Fail 'token file is empty' }

$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
if (-not $NotesPath) { $NotesPath = Join-Path $RepoRoot ("docs\fork-release-{0}.md" -f $Tag) }
if (-not $AssetPath) { $AssetPath = Join-Path $RepoRoot ("dsh-chat-manager-{0}.tgz" -f $Version) }
if (-not $CommitMessage) {
  $CommitMessage = @"
chore(release): v$Version for DSH 0.2.2-rc.1

- bump the unpublished v2 candidate 2.0.0-alpha.1 -> 2.0.0-alpha.2
- keep peerDependencies pinned to @deepseek-ai/dsh-client-* 0.2.2-rc.1 and @deepseek-ai/cordis 4.1.0
- document fork changes, local install/rollback and release procedure
"@
}

# Files this release carries. Paths are repo-relative, forward slashes as GitHub expects.
$changedFiles = @(
  'package.json',
  'tests/package-contract.test.mjs',
  'README.md',
  'README.en.md',
  'AGENTS.md',
  'docs/UNRELEASED-v2.md',
  '.gitignore',
  'FORK-NOTES.md',
  ('docs/fork-release-{0}.md' -f $Tag),
  'scripts/publish-fork-release.ps1'
)
$changedFiles = $changedFiles | Select-Object -Unique

foreach ($relative in $changedFiles) {
  $full = Join-Path $RepoRoot ($relative -replace '/', '\')
  if (-not (Test-Path -LiteralPath $full)) { Fail "missing file for the release: $relative" }
}
if (-not (Test-Path -LiteralPath $NotesPath)) { Fail "release notes not found: $NotesPath" }
if (-not $SkipAsset -and -not (Test-Path -LiteralPath $AssetPath)) { Fail "asset not found: $AssetPath" }

$headers = @{
  Authorization          = "Bearer $token"
  Accept                 = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
  'User-Agent'           = 'dsh-chat-manager-fork-release'
}
$api = 'https://api.github.com'
$repoApi = "$api/repos/$Owner/$Repo"

function Invoke-GitHub {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Uri,
    $Payload
  )
  $params = @{ Method = $Method; Uri = $Uri; Headers = $headers; ErrorAction = 'Stop' }
  if ($null -ne $Payload) {
    $json = $Payload | ConvertTo-Json -Depth 20 -Compress
    $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    $params.ContentType = 'application/json; charset=utf-8'
  }
  try {
    return Invoke-RestMethod @params
  } catch {
    $detail = $_.Exception.Message
    try {
      $response = $_.Exception.Response
      if ($response) {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $body = $reader.ReadToEnd()
        if ($body) { $detail = "$detail | $body" }
      }
    } catch { }
    Fail "$Method $Uri failed: $detail"
  }
}

# ---------- 1. identity ----------
Info "verifying token against $api"
$me = Invoke-GitHub -Method 'GET' -Uri "$api/user"
if ($me.login -ne $Owner -and -not $AllowDifferentAccount) {
  Fail "token belongs to '$($me.login)' but -Owner is '$Owner'. Re-run with -AllowDifferentAccount if that is intended."
}
Info "token account: $($me.login)"

$repoInfo = Invoke-GitHub -Method 'GET' -Uri $repoApi
if (-not $repoInfo.fork) { Write-Host "WARNING: $Owner/$Repo does not look like a fork (fork=false)" }
$branch = if ($repoInfo.default_branch) { $repoInfo.default_branch } else { 'main' }
Info "target: $($repoInfo.full_name) default branch '$branch'"

# ---------- 2. base commit ----------
$ref = Invoke-GitHub -Method 'GET' -Uri "$repoApi/git/ref/heads/$branch"
$baseSha = $ref.object.sha
$baseCommit = Invoke-GitHub -Method 'GET' -Uri "$repoApi/git/commits/$baseSha"
Info "base commit: $baseSha ($($baseCommit.message.Split("`n")[0]))"

# ---------- 3. refuse to clobber an existing tag / release ----------
$tagExists = $null
try { $tagExists = Invoke-GitHub -Method 'GET' -Uri "$repoApi/git/ref/tags/$Tag" } catch { $tagExists = $null }
if ($tagExists) { Fail "tag $Tag already exists in $Owner/$Repo" }
$releaseExists = $null
try { $releaseExists = Invoke-GitHub -Method 'GET' -Uri "$repoApi/releases/tags/$Tag" } catch { $releaseExists = $null }
if ($releaseExists) { Fail "release $Tag already exists in $Owner/$Repo" }

if ($DryRun) {
  Info 'DRY RUN — nothing was written'
  Write-Host "would create commit on $branch from $baseSha with files:"
  $changedFiles | ForEach-Object { Write-Host "  - $_" }
  Write-Host "would create tag $Tag and pre-release, asset: $(if ($SkipAsset) { '<skipped>' } else { $AssetPath })"
  return
}

# ---------- 4. blobs + tree ----------
$treeEntries = New-Object System.Collections.ArrayList
foreach ($relative in $changedFiles) {
  $bytes = [System.IO.File]::ReadAllBytes((Join-Path $RepoRoot ($relative -replace '/', '\')))
  $blob = Invoke-GitHub -Method 'POST' -Uri "$repoApi/git/blobs" -Payload @{
    content  = [Convert]::ToBase64String($bytes)
    encoding = 'base64'
  }
  [void]$treeEntries.Add(@{ path = $relative; mode = '100644'; type = 'blob'; sha = $blob.sha })
  Info "blob $($blob.sha.Substring(0, 10)) $relative"
}

$tree = Invoke-GitHub -Method 'POST' -Uri "$repoApi/git/trees" -Payload @{
  base_tree = $baseCommit.tree.sha
  tree      = @($treeEntries)
}
Info "tree: $($tree.sha)"

# ---------- 5. commit + branch update ----------
$commit = Invoke-GitHub -Method 'POST' -Uri "$repoApi/git/commits" -Payload @{
  message = $CommitMessage
  tree    = $tree.sha
  parents = @($baseSha)
}
Info "commit: $($commit.sha)"

$null = Invoke-GitHub -Method 'PATCH' -Uri "$repoApi/git/refs/heads/$branch" -Payload @{ sha = $commit.sha; force = $false }
Info "branch $branch fast-forwarded to $($commit.sha)"

# ---------- 6. annotated tag ----------
$tagObject = Invoke-GitHub -Method 'POST' -Uri "$repoApi/git/tags" -Payload @{
  tag     = $Tag
  message = "DSH Chat Manager $Version (fork release for DeepSeekRuntime 0.2.2-rc.1)"
  object  = $commit.sha
  type    = 'commit'
}
$null = Invoke-GitHub -Method 'POST' -Uri "$repoApi/git/refs" -Payload @{ ref = "refs/tags/$Tag"; sha = $tagObject.sha }
Info "tag $Tag -> $($tagObject.sha)"

# ---------- 7. release ----------
$releaseBody = [System.IO.File]::ReadAllText($NotesPath, [System.Text.Encoding]::UTF8)
if ([string]::IsNullOrWhiteSpace($releaseBody)) { Fail "release notes are empty: $NotesPath" }
$release = Invoke-GitHub -Method 'POST' -Uri "$repoApi/releases" -Payload @{
  tag_name   = $Tag
  name       = "v$Version " + [char]0x00B7 + " DSH 0.2.2-rc.1"
  body       = $releaseBody
  draft      = $false
  prerelease = $true
}
Info "release: $($release.html_url)"

# ---------- 8. asset ----------
if (-not $SkipAsset) {
  $assetName = Split-Path -Leaf $AssetPath
  Info "uploading $assetName"
  $uploadUri = "https://uploads.github.com/repos/$Owner/$Repo/releases/$($release.id)/assets?name=$([uri]::EscapeDataString($assetName))"
  try {
    $asset = Invoke-RestMethod -Method 'POST' -Uri $uploadUri -Headers $headers -InFile $AssetPath -ContentType 'application/gzip' -ErrorAction 'Stop'
    Info "asset: $($asset.browser_download_url)"
  } catch {
    Fail "release created but asset upload failed: $($_.Exception.Message)"
  }
}

Write-Host ''
Info "done"
Write-Host "release : $($release.html_url)"
Write-Host "tag     : https://github.com/$Owner/$Repo/releases/tag/$Tag"
Write-Host "commit  : https://github.com/$Owner/$Repo/commit/$($commit.sha)"
Write-Host ''
Write-Host "Remember to delete the token file when you are done: $TokenFile"
