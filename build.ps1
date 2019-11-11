$windows_builds = "$PSScriptRoot\win_builds"
function Depot-Tools-Installed {
    if (Get-Command "gclient" -ErrorAction SilentlyContinue) {
        return $True
    }
    return $False
}

function Build-WebRTC {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Target,
        [Parameter(Mandatory = $true, Position = 1)]
        [bool] $IsDebug
    )

    $is_debug = if ($IsDebug) { "true" } else { "false" }
    $build_name = if ($IsDebug) { "Debug" } else { "Release" }
    $output = "$windows_builds\$Target\$build_name"
    $symbol_level = if ($IsDebug) { 2 } else { 0 }
    $arguments = "is_clang=false use_rtti=true is_debug=$is_debug target_cpu=""""$Target"""" symbol_level=$symbol_level rtc_enable_sctp=true fatal_linker_warnings=false treat_warnings_as_errors=false rtc_include_tests=false"
    $gn = Start-Process "gn" -ArgumentList "gen $output --args=""$arguments""" -PassThru -Wait -NoNewWindow
    if ($gn.ExitCode -ne 0) {
        throw "Failed to generate build manifest for $output"
    }
    $ninja = Start-Process "ninja" -ArgumentList "-C $output" -PassThru -Wait -NoNewWindow
    if ($ninja.ExitCode -ne 0) {
        throw "Failed to build WebRTC for $output"
    }
}

function Copy-Libs {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Target,
        [Parameter(Mandatory = $true, Position = 1)]
        [bool] $IsDebug
    )
    $build_name = If ($IsDebug) { "Debug" } Else { "Release" }
    $library_location = "$windows_builds\$Target\$build_name"
    $output = "$PSScriptRoot\libs\$Target\$build_name"
    if (Test-Path $output) {
        Remove-Item -Path $output -Force -Recurse
    }
    New-Item -ItemType Directory -Force -Path ($output); Get-ChildItem -Recurse ($library_location) -Include ("webrtc.lib") | Copy-Item -Destination ($output)
}

function Copy-Includes {
    $includes_path = "$PSScriptRoot\includes"
    if (Test-Path $includes_path) {
        Write-Output "Cleaning up old includes..."
        # if exists: empty contents and reuse the directory itself
        Get-ChildItem $includes_path -Recurse | Remove-Item -Recurse -Force
    }
    else {
        New-Item $includes_path -ItemType Directory -Force 
    }
    Write-Output "Copying Includes"
    xcopy /s "$(Get-Location)\*.h" "$includes_path" /Q
    xcopy /s "$(Get-Location)\third_party\abseil-cpp\absl\*.h"  "$includes_path\absl\" /Q
    #Remove-Item -Path "$includes_path\third_party" -Force -Recurse
}

$depot_path = "$(Get-Location)\depot_tools"
$Env:Path += ";$depot_path"
$webrtc_head = "m76"


if ((Depot-Tools-Installed) -eq $false) {
    $download_path = "$(Get-Location)/depot_tools"
    $zip_path = Join-Path -Path $download_path -ChildPath "depot_tools.zip"
    New-Item -ItemType Directory -Path $download_path -Force | Out-Null
    Write-Output "Downloading depot tools to $zip_path..."
    (new-object System.Net.WebClient).DownloadFile('https://storage.googleapis.com/chrome-infra/depot_tools.zip', $zip_path);
    Write-Output "Extracting depot tools to $download_path..."
    Expand-Archive $zip_path -DestinationPath $download_path -Force
    Write-Output "Deleting $zip_path..."
    Remove-Item -Path $zip_path -Force -ErrorAction Ignore
    Write-Output $download_path
}

$checkout_path = "$(Get-Location)\webrtc"

if (Test-Path $checkout_path) {
    Write-Output "Cleaning up last checkout..."
    Remove-Item -LiteralPath $checkout_path -Force -Recurse
    Write-Output "Done."
}

New-Item -ItemType Directory -Path $checkout_path

Set-Location -Path $checkout_path

Write-Output "Fetching WebRTC"

$fetch_process = Start-Process "fetch" -ArgumentList "--nohooks webrtc" -PassThru -Wait -NoNewWindow
if ($fetch_process.ExitCode -ne 0) {
    throw "Failed to fetch WebRTC."
}

Set-Location -Path "$checkout_path\src"

Write-Output "Checking out remote header $webrtc_head..."

$checkout = Start-Process "git" -ArgumentList "checkout -b spitfire refs/remotes/branch-heads/$webrtc_head" -PassThru -Wait -NoNewWindow
if ($checkout.ExitCode -ne 0) {
    throw "Failed to checkout remote WebRTC branch"
}

Write-Output "Syncing repo..."

$gclient = Start-Process "gclient" -ArgumentList "sync" -PassThru -Wait -NoNewWindow
if ($gclient.ExitCode -ne 0) {
    throw "Failed to sync WebRTC code. $($gclient.ExitCode)"
}

Write-Output "Applying patches..."

Get-ChildItem "$PSScriptRoot\patches" -Filter *.patch | 
Foreach-Object {
    $name = $_.FullName
    $diff = Start-Process "git" -ArgumentList "apply $name" -PassThru -Wait -NoNewWindow
    if ($diff.ExitCode -ne 0) {
        throw "Failed to apply diff $name"
    }
    Write-Output "Applied $name"
}

Write-Output "Replacing BUILD.gn"
Copy-Item "$PSScriptRoot\configs\BUILD.gn" -Destination "$(Get-Location)\build\config\win\BUILD.gn" -force


if (Test-Path $windows_builds) {
    Write-Output "Cleaning up old builds..."
    Remove-Item -LiteralPath $windows_builds -Force -Recurse
    Write-Output "Done."
}

Write-Output "Building x64 Debug"
Build-WebRTC -Target "x64" -IsDebug $true
Write-Output "Building x64 Release"
Build-WebRTC -Target "x64" -IsDebug $false
Write-Output "Building x86 Debug"
Build-WebRTC -Target "x86" -IsDebug $true
Write-Output "Building x86 Release"
Build-WebRTC -Target "x86" -IsDebug $false

Write-Output "Copying x64 Libraries"
Copy-Libs -Target "x64" -IsDebug $true
Copy-Libs -Target "x64" -IsDebug $false
Write-Output "Copying x86 Libraries"
Copy-Libs -Target "x86" -IsDebug $true
Copy-Libs -Target "x86" -IsDebug $false

Copy-Includes


Write-Output "WebRTC Built!"










