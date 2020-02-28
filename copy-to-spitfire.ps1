$input = "$(Get-Location)"
$output = "$(Get-Location)\..\spitfire" # Assumes webrtc-build-scripts and spitfire are at the same directory level

Remove-Item -LiteralPath "$output\include" -Force -Recurse
Remove-Item -LiteralPath "$output\lib" -Force -Recurse

robocopy /NFL /NDL /NJH /NJS /NC /NS /NP /E "$input\includes" "$output\include"
robocopy /NFL /NDL /NJH /NJS /NC /NS /NP /E "$input\libs" "$output\lib"
