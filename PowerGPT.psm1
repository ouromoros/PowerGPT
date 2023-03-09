function Send-LlmPromptChat {
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$Model = "gpt-3.5-turbo",
        
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
        [PSCustomObject[]]$Messages,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$API_KEY
    )

    $body = @{
        model = $Model
        messages = $Messages
        max_tokens = $MaxTokens
        temperature = $Temperature
        top_p = $TopP
        n = $N
        stream = $false
        stop = $Stop
    }

    # Send request to openai completion API
    $endpoint = "https://api.openai.com/v1/chat/completions"
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

function Get-PromptMessages {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserPrompt,
        [Parameter(Mandatory=$true)]
        [string]$ShellVariant
    )

    $SystemPromptContent = "You are a powerful and sophisticated multi-lingual chat bot that generates script given the user's instruction.
User will describe the task followed by desired response script language. You will respond with a step-by-step explanation of how to construct the script followed by the full script.
When you cannot interpret user's intention or user's instruction is too vague and can have different imterpretations, you will make inference about user's intention and present them as choices for user.
When user's message is unrelated to a task, You will respond BEEP.
You must return a script that matches user's instruction.
The script must be runnable in script environment.
The script must be correct and contain no bugs or potential bugs.
The script must do exactly what the instruction says.
The script should only use commands that's available in the script environment.
The script should follow best practice and conform to style guides.
The script should be the most frequently used one.
The script should be clear and readable.
The script should be well documented.
Your response must only be providing script or choices and should not do both at the same time.
"
    $DemoUserMessage0 = "list all files in current directory"
    $DemoAssitantMessage0 = "
we use ``Get-ChildItem`` to get all files in current directory.
``````
Get-ChildItem
``````"
    $DemoUserMessage1 = "what's the weather today?"
    $DemoAssitantMessage1 = "BEEP"
    $DemoUserMessage21 = "print first lines and last lines of files in current folder | PowerShell"
    $DemoAssitantMessage21 = "
The instruction is unclear, do you mean one of these:
[0] For each file in current directory, print the first line and then print the last line of the file.
[1] For each file in current directory, print the first line of the file. After that, for each file, print the last line of the file."
    $DemoUserMessage22 = "For each file in current directory, print the first line and then print the last line of the file."
    $DemoAssitantMessage22 = "
First we use `Get-ChildItem` to get all files in current directory. Then we use `ForEach-Object` to iterate through each file. For each file, we use `Get-Content` to get the first line and the last line of the file. We use `Write-Host` to print the first line and the last line of the file.
``````
Get-ChildItem | ForEach-Object {
    `$file = `$_.FullName
    Write-Host `"First line of `$file:`"
    Get-Content `$file -TotalCount 1
    Write-Host `"Last line of `$file:`"
    Get-Content `$file -Tail 1
}
``````"
    $DemoUserMessage3 = "列出当前文件夹下所有文件 | Windows PowerShell"
    $DemoAssitantMessage3 = "
我们使用``Get-ChildItem``来列出当前文件夹下所有文件。
``````
Get-ChildItem
``````"
    $DemoUserMessage4 = "extract compressed.tar.gz | Windows PowerShell"
    $DemoAssitantMessage4 = "
First we use `Get-Command` to check if the ``tar`` command is available. If not, we use ``Invoke-WebRequest`` to download the ``tar.exe.zip`` file. Then we use ``Expand-Archive`` to extract the ``tar.exe.zip`` file. After that, we add the ``tar`` command to the ``PATH`` environment variable. Finally, we use ``tar`` to extract the ``compressed.tar.gz`` file.
``````
# Extract compressed.tar.gz in Windows using PowerShell
# First, check if the tar command is available
if (!(Get-Command tar -ErrorAction SilentlyContinue)) {
    # If not, install the tar command
    Invoke-WebRequest -Uri ""http://gnuwin32.sourceforge.net/downlinks/tar.exe.zip"" -OutFile ""tar.exe.zip""
    Expand-Archive -Path ""tar.exe.zip"" -DestinationPath ""`$env:ProgramFiles\GnuWin32""
    # Add the tar command to the PATH
    `$env:Path += "";`$env:ProgramFiles\GnuWin32""
}
# Extract the compressed.tar.gz file
tar -xvzf compressed.tar.gz
``````"

    $UserPromptContent = "$UserPrompt | $ShellVariant"

    $FullPromptMessages = @(
        @{ "role" = "system"; "content" = $SystemPromptContent },
        @{ "role" = "user"; "content" = $DemoUserMessage0 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage0.Trim() },
        @{ "role" = "user"; "content" = $DemoUserMessage1 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage1.Trim() },
        @{ "role" = "user"; "content" = $DemoUserMessage21 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage21.Trim() },
        @{ "role" = "user"; "content" = $DemoUserMessage22 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage22.Trim() },
        @{ "role" = "user"; "content" = $DemoUserMessage3 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage3.Trim() },
        @{ "role" = "user"; "content" = $DemoUserMessage4 },
        @{ "role" = "assistant"; "content" = $DemoAssitantMessage4.Trim() },
        @{ "role" = "user"; "content" = $UserPromptContent }
    )
    return $FullPromptMessages
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

    $Config = Read-Configuration -ResetConfig:$ResetConfig
    # We use text-chat-davinci-002 and set temparature to 0
    # Temparature controls "creativeness" according to https://platform.openai.com/docs/api-reference/completions/create
    # We set it to 0 to avoid false results
    $PromptMessages = Get-PromptMessages -UserPrompt $Prompt -ShellVariant $ShellVariant
    Write-Host ($PromptMessages | ConvertTo-Json)
    $Result = Send-LlmPromptChat -Messages $PromptMessages -Temperature 0 -ErrorAction Stop -API_KEY $Config.API_KEY
    $ResultText = $Result.choices[0].message.content.Trim() # Response will often contain newline characters, we just trim to remove them

    # Check if response is a script or 
    if ($ResultText.StartsWith("Unacknowledged.")) {
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

        $PromptMessages.Add(@{ "role" = "user"; "content" = $Opt })
        $Result = Send-LlmPromptChat -Messages $PromptMessages -Temperature 0 -ErrorAction Stop -API_KEY $Config.API_KEY
        $ResultText = $Result.choices[0].message.content.Trim()
    }

    if ($ResultText -eq "BEEP") {
        Write-Host "**BEEP** PowerGPT bot failed to understand your input **BEEP**"
        return
    }

    Write-Host $ResultText
    $startIndex = $ResultText.IndexOf("``````") + 3
    $endIndex = $ResultText.IndexOf("``````", $startIndex)
    $ScriptText = $ResultText.SubString($startIndex, $endIndex - $startIndex)

    if ($Print -or ($ShellVariant -ne "Windows PowerShell")) {
        Write-Output $ScriptText
    } else {
        $Execute = $true
        Write-Host "Will execute script:`n-----`n$ScriptText`n-----"
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
            Invoke-Expression $ScriptText
        }
    }
}

Export-ModuleMember -Function PowerGPT
