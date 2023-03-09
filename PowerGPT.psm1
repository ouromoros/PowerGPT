function Send-LlmPrompt {
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Model = "text-davinci-003",
        
        [Parameter(Mandatory=$false)]
        [int]$MaxTokens = 400,

        [Parameter(Mandatory=$false)]
        [int]$N = 1,

        [Parameter(Mandatory=$false)]
        [float]$Temperature = 1,

        [Parameter(Mandatory=$false)]
        [float]$TopP = 1,

        [Parameter(Mandatory=$false)]
        [string]$Stop = $null,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Prompts,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$API_KEY
    )

    $body = @{
        model = $Model
        prompt = $Prompts
        max_tokens = $MaxTokens
        temperature = $Temperature
        top_p = $TopP
        n = $N
        stream = $false
        logprobs = $null
        stop = $Stop
    }

    # Send request to openai completion API
    $endpoint = "https://api.openai.com/v1/completions"
    $headers = @{
        "Content-Type"="application/json"
        "Authorization"="Bearer $API_KEY"
    }

    $jsonPayload = ConvertTo-Json $body
    # Write-Host -ForegroundColor Yellow "POST $endpoint"
    # $headers.Keys | %{ if ($_ -eq "Authorization") { Write-Host "Authorization: Bearer (...)" } else { Write-Host "$($_): $($headers.$_)" }}
    # Write-Host $jsonPayload

    # Write-Host -ForegroundColor Yellow "Response:"
    $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body $jsonPayload -UseDefaultCredentials
    return $result
}

function Read-Configuration {
    param (
        [switch]
        $ResetConfig
    )

    $ConfigPath = Join-Path $HOME "PowerGPT.config.json"
    if ($ResetConfig -and (Test-Path $ConfigPath)) {
        Remove-Item $ConfigPath -Force
    }
    # Check if config file exists, if it doesn't, create it
    if (-not (Test-Path $ConfigPath)) {
        $API_KEY = (Read-Host -Prompt "Input your API key").Trim()
        $Config = @{
            API_KEY = $API_KEY
        }
        # Store config to config path
        $Config | ConvertTo-Json | Out-File $ConfigPath
        return $Config
    }
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
    return $Config
}

function PowerGPT {
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
        [string]$ShellVariant = "Windows PowerShell"
    )

    $FullPrompt = "PowerGPT is a powerful and sophisticated chat bot that generates script given the user's instruction.
User will describe the task in natural language and PowerGPT will respond with a script.
When user's message is unrelated to a task, PowerGPT will respond BEEP.
PowerGPT will return script that matches user's instruction.
The script must be runnable in script environment.
The script must be correct and contain no bugs or potential bugs.
The script must do exactly what the instruction says.
The script should only use commands that's available in the script environment.
The script should follow best practice and conform to style guides.
The script should be the most frequently used one.
The script should be clear and readable.
The script should be well documented.
When PowerGPT cannot interpret user's intention or user's instruction is too vague and can have different imterpretations, PowerGPT will make inference about user's intention and present them as choices for user. The number of choices should not exceed 5. Each choice will be prepended by a serial number. Each choice is a short description of what the user is likely to want to do. Each choice will take one line. User will respond with one number. Then PowerGPT must respond with the script.

Below are some examples of user interacting with PowerGPT. Each interaction between user and PowerGPT will start with INTERACTION_START and the context language user is interested in. The interaction will end with INTERACTION_END. Each response of PowerGPT will start with POWERGPT_START and end with POWERGPT_END.

INTERACTION_START `"Windows PowerShell`"
User:
list all files in current directory
PowerGPT:
POWERGPT_START
Get-ChildItem
POWERGPT_END
INTERACTION_END

INTERACTION_START `"Windows PowerShell`"
User:
print first lines and last lines of files in current folder
PowerGPT:
POWERGPT_START
[0] For each file in current directory, print the first line and then print the last line of the file.
[1] For each file in current directory, print the first line of the file. After that, for each file, print the last line of the file.
POWERGPT_END
User:
[0]
PowerGPT:
POWERGPT_START
Get-ChildItem | ForEach-Object {
    `$file = `$_.FullName
    Write-Host `"First line of `$file:`"
    Get-Content `$file -TotalCount 1
    Write-Host `"Last line of `$file:`"
    Get-Content `$file -Tail 1
}
POWERGPT_END
INTERACTION_END

INTERACTION_START `"$ShellVariant`"
User:
$Prompt
PowerGPT:
POWERGPT_START
"

    $Config = Read-Configuration -ResetConfig:$ResetConfig
    # We use text-chat-davinci-002 and set temparature to 0
    # Temparature controls "creativeness" according to https://platform.openai.com/docs/api-reference/completions/create
    # We set it to 0 to avoid false results
    $Result = Send-LlmPrompt -Prompts @($FullPrompt) -Stop "POWERGPT_END" -Temperature 0 -ErrorAction Stop -API_KEY $Config.API_KEY
    $ResultText = $Result.choices[0].text.Trim() # Response will often contain newline characters, we just trim to remove them

    # Check if response is a script or 
    if ($ResultText[0] -eq "[" -and $ResultText[1] -le "9" -and $ResultText[1] -ge "0" -and $ResultText[2] -eq "]") {
        Write-Host "The description is a little vague, do you mean:"
        Write-Host $ResultText

        $NumOfChoices = $ResultText.split("`n").Count
        $Choice = -1
        while ($true) {
            $Opt = Read-Host -Prompt "Choose one description that matches your task, or [n]o"
            if ($Opt[0] -eq "n") {
                #user chooses to end flow
                return
            }

            $Success = [int]::tryparse($Opt,[ref]$Choice)
            if ($Success -and ($Choice -ge 0) -and ($Choice -lt $NumOfChoices)) {
                break
            }
        }

        $FullPromptWithHistory = $FullPrompt + $ResultText + "`nPOWERGPT_END`nUser:`n[$Choice]`nPowerGPT:`nPOWERGPT_START`n"
        $Result = Send-LlmPrompt -Prompts @($FullPromptWithHistory) -Stop "POWERGPT_END" -Temperature 0 -ErrorAction Stop -API_KEY $Config.API_KEY
        $ResultText = $Result.choices[0].text.Trim()
    }

    if ($ResultText -eq "BEEP") {
        Write-Host "**BEEP** PowerGPT bot failed to understand your input **BEEP**"
        return
    }

    if ($Print -or ($ShellVariant -ne "Windows PowerShell")) {
        Write-Output $ResultText
    } else {
        $Execute = $true
        Write-Host "Will execute script:`n-----`n$ResultText`n-----"
        # Prompt to ask if user wants to continue execute script
        while ($true) {
            $Opt = Read-Host -Prompt "continue?([y]es, [n]o)"
            if ($Opt -eq "y") {
                break
            }
            if ($Opt -eq "n") {
                $Execute = $false
                break
            }
        }

        if ($Execute) {
            Invoke-Expression $ResultText
        }
    }
}

Export-ModuleMember -Function PowerGPT
