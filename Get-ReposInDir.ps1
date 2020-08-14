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
function Walk-Directory([String]$parent) {
    # Walk through all directories in the passed in Root Directory
    $children = Get-ChildItem -Path $parent -Directory
    foreach($d in $children) {
        cd $d.FullName
        # Try if this is a git repo
        $remoteName = git remote 2> $null
        if($? -eq $True) {
            $repoName = git remote get-url origin 2> $null
            if($? -eq $True ) {
                if($operation -eq "dump") {
                    Write-Output "git clone $repoName"
                } elseif ($operation -eq "pull") {
                    git pull
                } elseif ($operation -eq "status") {
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
Walk-Directory($rootDir)
cd $currentPath