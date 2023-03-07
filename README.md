## PowerGPT

A command line helper for running commands with aid from GPT model.

The script is implemented purely in PowerSell and packaged as a PowerShell module.

```
Install-Module PowerGPT
```

## Usage

Basic Usage:

```powershell
$ PowerGPT "list all files in current folder with created date"
Will execute script:
-----
Get-ChildItem | Select-Object Name, CreationTime
-----
continue?([y]es, [n]o): 

$ PowerGPT "extract compressed.tar.gz"
Will execute script:
-----
# Extract compressed.tar.gz in Windows using PowerShell
# First, check if the tar command is available
if (!(Get-Command tar -ErrorAction SilentlyContinue)) {
    # If not, install the tar command
    Invoke-WebRequest -Uri "http://gnuwin32.sourceforge.net/downlinks/tar.exe.zip" -OutFile "tar.exe.zip"
    Expand-Archive -Path "tar.exe.zip" -DestinationPath "$env:ProgramFiles\GnuWin32"
    # Add the tar command to the PATH
    $env:Path += ";$env:ProgramFiles\GnuWin32"
}
# Extract the compressed.tar.gz file
tar -xvzf compressed.tar.gz
-----
continue?([y]es, [n]o):
```
```powershell
$ PowerGPT "print the first line of all the files that begin with poet_ in current folder"
Will execute script:
-----
Get-ChildItem -Path . -Filter "poet_*" | ForEach-Object {Get-Content $_.FullName | Select-Object -First 1}
-----
continue?([y]es, [n]o):
```

For complex task, the tool will behave smartly and provide choices for user:

```powershell
$ .\PowerGPT.ps1 "print first lines and last lines for each file in current folder"
The description is too vague, do you mean:
[0] For each file in current directory, print the first line and then print the last line of the file.
[1] For each file in current directory, print the first line of the file. After that, for each file, print the last line of the file.
Choose one description that matches your task: : 1
Will execute script:
-----
Get-ChildItem | ForEach-Object {
    $file = $_.FullName
    Write-Host "First line of $file:"
    Get-Content $file -TotalCount 1
}
Get-ChildItem | ForEach-Object {
    $file = $_.FullName
    Write-Host "Last line of $file:"
    Get-Content $file -Tail 1
}
-----
continue?([y]es, [n]o)
```

It's also possible for it to write script using common library in other languages:

```powershell
$ .\PowerGPT.ps1 "retrieve AzureDevops artifact for a build" -ShellVariant C#
The description is a little vague, do you mean:
[0] Use AzureDevops REST API to retrieve the artifact for a build.
[1] Use AzureDevops SDK to retrieve the artifact for a build.
Choose one description that matches your task, or [n]o: 0
using System;
using System.Net.Http;
using System.Threading.Tasks;

class Program
{
    static async Task Main(string[] args)
    {
        var organization = "your_organization";
        var project = "your_project";
        var buildId = "your_build_id";
        var token = "your_token";

        var client = new HttpClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var url = $"https://dev.azure.com/{organization}/{project}/_apis/build/builds/{buildId}/artifacts?api-version=5.1";
        var response = await client.GetAsync(url);
        var content = await response.Content.ReadAsStringAsync();
        Console.WriteLine(content);
    }
}
```
