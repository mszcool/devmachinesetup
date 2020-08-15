Param(
    [String]
    $rootDir,
    [String]
    [ValidateSet("dump", "pull", "status")]
    $operation
)

#
# Function for walking a directory
#
function Step-Directory([String]$parent, [String]$op) {
    # Walk through all directories in the passed in Root Directory
    $children = Get-ChildItem -Path $parent -Directory
    foreach($d in $children) {
        Set-Location $d.FullName
        # Try if this is a git repo
        $remoteName = git remote 2> $null
        if($? -eq $True) {
            $repoName = git remote get-url $remoteName 2> $null
            if($? -eq $True ) {
                if($op -eq "dump") {
                    Write-Output "git clone $repoName"
                } elseif ($op -eq "pull") {
                    git pull
                } elseif ($op -eq "status") {
                    git status
                } else {
                    Write-Output "$PWD"
                }
            }
        } else {
            Walk-Directory($d.FullName)
        }
    }
}

$currentPath = $PWD.Path
Step-Directory($rootDir, $operation)
Set-Location $currentPath