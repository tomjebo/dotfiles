function Get-GitStatus { git status $args }
New-Alias -Name gs -Value Get-GitStatus

function Get-GitAllBranches { git branch --all -v $args }
New-Alias -Name gba -Value Get-GitAllBranches
function Get-GitBranches { git branch $args }
New-Alias -Name gb -Value Get-GitBranches
function SetTabName { 
if ($args.count -gt 0) { 
	$tabName = $args[0] 
}
else {
	$tabName = Split-Path -Path $(get-location) -Leaf 
}

$host.ui.RawUI.WindowTitle = $tabName
}

New-Alias -Name stn -Value SetTabName

function ghil {
    gh issue list -a tomjebo
}

function Search-File {
    param(
        [string]$Path,
        [string]$Pattern
    )

    Get-ChildItem -Path $Path -Recurse | Where-Object { $_.Name -like $Pattern }
}

Set-Alias -Name sf -Value Search-File
#Now you can use sf C:\Users\* .txt to search for text files in the user's directory.

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
	Import-Module "$ChocolateyProfile"
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
	param($wordToComplete, $commandAst, $cursorPosition)
		dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
			[System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
		}
}

$host.ui.RawUI.WindowTitle = Split-Path -Path $(get-location) -Leaf
