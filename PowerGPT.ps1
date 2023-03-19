param (
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$Prompt,

    [switch]
    $Print,

    [switch]
    $ResetConfig,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ShellVariant = "Windows PowerShell",

    [switch]
    $Chat
)

Import-Module .\PowerGPT.psm1 -Force

PowerGPT -Prompt $Prompt -ShellVariant $ShellVariant -ResetConfig:$ResetConfig -Chat:$Chat
