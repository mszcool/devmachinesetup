Param(
  [String]
  [ValidateSet(
       "docker",
       "CanonicalGroupLimited.Ubuntu18.04onWindows_79rhkp1fndgsc",
       "CanonicalGroupLimited.Ubuntu20.04onWindows_79rhkp1fndgsc")]
  $targetDistro,

  [String]
  $targetDirectory
)

if ($targetDistro == "docker")
{
    $source = "$env:USERPROFILE\AppData\Local\Docker\wsl"
    $diskRel = "data"
}
else
{
    $source = "$env:USERPROFILE\AppData\Local\Packages\$targetDistro"
    $diskRel = "LocalState"
}

wsl --shutdown
Move-Item "$source\$diskRel\*.*" "$targetDirectory"
Remove-Item "$source\$diskRel"
New-Item -ItemType SymbolicLink -Path "$source\$diskRel" -Target "$targetDirectory"