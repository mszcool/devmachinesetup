Param (
    [Parameter(Mandatory=$true)]
    [string]
    $relativePath
)

#
# Get the content of the file relative from the hosts' working directory
#
$workingPath = Get-Location
$targetPath = [System.IO.Path]::Combine($workingPath, $relativePath)
Write-Host "Verifying syntax of '$targetPath' ..."

#
# Next test if the file exists
#
if ( -not [System.IO.File]::Exists($targetPath) ) {
    Write-Error "File '$targetPath' does not exist!"
    exit -1
}

#
# If it does exist, read its contents and verify its syntax
#
$errors = $null
$content = Get-Content -Path $targetPath -ErrorAction Stop
$null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)

if ( $null -eq $errors ) {
    exit 0
}
else {
    $errors | ForEach-Object {
        Write-Host "Error: $_.Message"
    }
    exit $errors.Count
}