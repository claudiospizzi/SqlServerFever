[![GitHub Release](https://img.shields.io/github/v/release/claudiospizzi/SqlServerFever?label=Release&logo=GitHub&sort=semver)](https://github.com/claudiospizzi/SqlServerFever/releases)
[![GitHub CI Build](https://img.shields.io/github/actions/workflow/status/claudiospizzi/SqlServerFever/pwsh-ci.yml?label=CI%20Build&logo=GitHub)](https://github.com/claudiospizzi/SqlServerFever/actions/workflows/pwsh-ci.yml)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/SqlServerFever?label=PowerShell%20Gallery&logo=PowerShell)](https://www.powershellgallery.com/packages/SqlServerFever)
[![Gallery Downloads](https://img.shields.io/powershellgallery/dt/SqlServerFever?label=Downloads&logo=PowerShell)](https://www.powershellgallery.com/packages/SqlServerFever)

# SqlServerFever PowerShell Module

PowerShell Module with custom functions and cmdlets related to SQL Server.

## Introduction

This Module should help to work with SQL Server for operations and migrations.

## Features

* **Connect-SqlServer**  
  Validate the connection details and store them in the default parameter values for SQL commands.

* **Test-SqlConnection**  
  Test the SQL connection to a target SQL Server and return details like protocol, encryption, version, edition, uptime and more.

* **Invoke-SqlDbCopy**  
  Invoke a SQL Server database copy with full control over source/target server and database. It will rename SQL files and set the owner to the default sa user.

* **Get-SqlDbTrxLogState**  
  Get the current state of a transaction log file for a database, including the number of virtual log files (VLFs) and the file size in MB.

* **Invoke-SqlDbTrxLogShrink**  
  Invoke a shrink operation for a transaction log file of a database. As the shrinking requires a process of transaction log backup and shrink operations, they are combined in this command.

## Versions

Please find all versions in the [GitHub Releases] section and the release notes in the [CHANGELOG.md] file.

## Installation

Use the following command to install the module from the [PowerShell Gallery], if the PackageManagement and PowerShellGet modules are available:

```powershell
# Download and install the module
Install-Module -Name 'SqlServerFever'
```

Alternatively, download the latest release from GitHub and install the module manually on your local system:

1. Download the latest release from GitHub as a ZIP file: [GitHub Releases]
2. Extract the module and install it: [Installing a PowerShell Module]

## Requirements

The following minimum requirements are recommended to use this module. It used to work on older versions and other platforms too, but they are not officially supported or tested.

* Windows 11 / PowerShell 7

## Contribute

Please feel free to contribute by opening new issues or providing pull requests. For the best development experience, open this project as a folder in Visual Studio Code and ensure that the PowerShell extension is installed.

* [Visual Studio Code] with the [PowerShell Extension]
* [Pester], [PSScriptAnalyzer], [InvokeBuild] and [InvokeBuildHelper] modules

[PowerShell Gallery]: https://www.powershellgallery.com/packages/SqlServerFever
[GitHub Releases]: https://github.com/claudiospizzi/SqlServerFever/releases
[Installing a PowerShell Module]: https://learn.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module

[CHANGELOG.md]: CHANGELOG.md

[Visual Studio Code]: https://code.visualstudio.com/
[PowerShell Extension]: https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell
[Pester]: https://www.powershellgallery.com/packages/Pester
[PSScriptAnalyzer]: https://www.powershellgallery.com/packages/PSScriptAnalyzer
[InvokeBuild]: https://www.powershellgallery.com/packages/InvokeBuild
[InvokeBuildHelper]: https://www.powershellgallery.com/packages/InvokeBuildHelper
