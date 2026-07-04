#Requires -Version 5.1

# User must open its execution policy by running
# `Set-ExecutionPolicy -ExecutionPolicy Unrestricted`
# and choose "Yes to All"

param(
  [Alias("logs", "log")]
  [switch]$LogsEnabled = $false
)

# the version of this script itself, useful to know if a user is running the latest version
$version = "1.2.1"

# the label of the WSL machine. Still based on Debian, but this label makes sure we get the
# machine created by this script and not some pre-existing Debian the user had.
$wslLabel = "PSBBN"

# the name of the exfat volume created by the psbbn installer with apajail
# this is used to attempt to detect which disks have an install of PSBBN
$oplVolumeName = "OPL"

# a list of subfolders to be created in the main folder if missing
$defaultFolders = @('DVD', 'CD', 'POPS', 'APPS', 'music', 'movie', 'photo')

# the specific git branch to be checked out
$gitBranch = "PSBBN-Definitive-Project-v4.2"

# the console size that is set at the start of the script
$consoleWidth = 110
$consoleHeight = 45

# the filename of the file holding the last path used
$pathFilename = "path.cfg"

# the minimum disk size allowed to be picked, in gigabytes
$minimumDiskSize = 31

# where the network drive chosen by the user will be mounted in wsl
$networkDriveMountpoint = "/mnt/PSBBN-network-drive"

# --- DO NOT MODIFY THE VARIABLES BELOW ---

# the escape character used to color text
$e = [char] 27

# this make wsl commands output utf8 instead of utf16_LE
$env:WSL_UTF8 = 1

# flag potentially raised when enabling features, signaling a reboot is necessary to finish the install
$global:isRestartRequired = $false

# stores Get-Disk's result to avoid multiple calls
$global:diskList = $null

# stores the disk number (obtained with Get-Disk) that was selected via diskPicker
$global:selectedDisk = -1

# keeps track of if a drive was manually mounted (for example a network drive)
$global:isDriveMounted = $false

function main {
  # set the console size so it matches the other scripts
  $host.UI.RawUI.WindowSize = New-Object `
    -TypeName System.Management.Automation.Host.Size `
    -ArgumentList ($consoleWidth, $consoleHeight)

  $PSDefaultParameterValues['*:Encoding'] = 'utf8'

  clear
  printTitle
  Write-Host "Prepare Windows to run the PSBBN scripts.`n"
  
  # check the minimum windows build version necessary for wsl
  $buildNumber = [System.Environment]::OSVersion.Version.Build
  if ($buildNumber -lt 19041) {
    Write-Host "
    ❌ Your Windows version is not up-to-date.
    Your build is $buildNumber. A build above 19041 is required.
    " -ForegroundColor Red
    Exit
  }

  # check if mandatory windows features are enabled
  Write-Host "Checking if the mandatory features are enabled..."
  # enable WSL as needed
  checkAndEnableFeature("Microsoft-Windows-Subsystem-Linux")
  # enable Hyper V as needed
  checkAndEnableFeature("HypervisorPlatform")
  # enable Virtual Maching Platform as needed
  checkAndEnableFeature("VirtualMachinePlatform")

  # detect if virtualization is enabled in BIOS
  detectVirtualization

  if ($isRestartRequired) {
    Write-Host "
    You need to restart your computer in order for some newly installed features to work properly.
    Once you have restarted, just run this script again.
" -ForegroundColor Yellow
    do {
      clearLines(1)
      $keyPressed = Read-Host "⚠️ You are about to restart your PC. Save your work, type `"restart`" and press ENTER"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'restart')

    if ($keyPressed -eq 'restart') {
      Restart-Computer
    }
    Exit
  }

  # check if wsl exists
  if (-Not (Get-Command wsl -errorAction SilentlyContinue)) {
    Write-Host "❌ WSL is not available on this computer." -ForegroundColor Red
    Exit
  }

  # fetch the latest wsl update
  Write-Host "Check the latest WSL updates...`t`t`t" -NoNewline
  $null = wsl --update --web-download
  $null = wsl --install --no-distribution
  printOK

  # check if a wsl distro is installed already
  $isWslInstalled = wsl --list | Select-String -SimpleMatch -Quiet $wslLabel
  if (-Not ($isWslInstalled)) {
    Write-Host "`nThe WSL distro will prompt you to set a username and a password." -ForegroundColor Yellow
    Write-Host "⚠️ The username must start with a lowercase letter, and only contain letters and numbers." -ForegroundColor Red
    Write-Host "⚠️ A password must be set." -ForegroundColor Red
    Write-Host "After this is done, you can type 'exit' and press enter to return to this script.`n" -ForegroundColor Yellow
    Write-Host "------- Linux magic starts ---------"

    wsl --install --distribution Debian --version 2 --name $wslLabel
  } else {
    Write-Host "The WSL distro is already present, skipping.`t" -NoNewline
    printOK
  }

  # install git if it is missing
  wsl -d $wslLabel -- type git `&`> /dev/null `|`| `(sudo apt update `&`& sudo apt -y install git`)

  # check that git is properly installed before continuing. Some network configurations can cause apt to fail to reach the repos
  if (-Not (wsl -d $wslLabel -- type git `2`> /dev/null)) {
    Write-Host "
    ❌ The script was unable to install git so it cannot continue.
    Check your internet connection and try to run the script again.
    If the issue persists, try setting your wsl networking mode to `"mirrored`" and try again.
    To do so, open the `"WSL Settings`" app then open the `"Networking`" tab.
    There you should see the option `"Networking Mode`". Select `"Mirrored`".
    " -ForegroundColor Red
    Exit
  }
  
  # if a folder with the previous name of the git repository exists,
  # rename it and move the git remote origin to the new url
  wsl -d $wslLabel --cd "~" -- [ -d ./PSBBN-Definitive-English-Patch ] `
    `&`& `( `
      mv ./PSBBN-Definitive-English-Patch ./PSBBN-Definitive-Project `
      `&`& cd PSBBN-Definitive-Project/ `
      `&`& git remote set-url origin https://github.com/CosmicScale/PSBBN-Definitive-Project.git `
    `)

  # clone the PSBBN repo into ~, or pull if it's already there
  Write-Host
  wsl -d $wslLabel --cd "~" -- [ -d PSBBN-Definitive-Project/.git ] `
    `&`& `( `
      cd PSBBN-Definitive-Project/ `
      `&`& git fetch origin $gitBranch `
      `&`& git checkout $gitBranch `
      `&`& git pull --ff-only `
    `) `
    `|`| git clone -b $gitBranch https://github.com/CosmicScale/PSBBN-Definitive-Project.git

  if (-Not ($isWslInstalled)) {
    Write-Host "------- Linux magic finishes ---------`n"
  }

  # prompt user to choose a disk
  diskPicker

  # mount the disk
  mountDisk

  # give the user the opportunity to put games/homebrew in the PSBBN folder
  $path = getTargetPath
  $wslPath = prepareWslPath($path)
  
  explorer $path
  pause
  clear

  # run PSBBN regular steps
  wsl -d $wslLabel --cd "~/PSBBN-Definitive-Project" -- `
    ./PSBBN-Definitive-Patch.sh -wsl $global:diskList[$selectedDisk].SerialNumber $wslPath

  # clear the terminal to get rid of the wsl-run scripts
  clear
  printTitle

  # unmount the target path if needed (in case of network drive)
  unmountTargetPath

  # unmount the disk before exiting
  unmountDisk

  # ensures wsl doesnt run out of resources if this script is ran repeatedly

  $wslDistrosCount = ((wsl --list --quiet) | Where-Object { $_.Trim() -ne "" }).Count
  if ($wslDistrosCount -eq 1) {
    wsl --shutdown
  } elseif ($wslDistrosCount -gt 1) {
    wsl --terminate $wslLabel
  }

  Write-Host "`nHave fun exploring PSBBN!`n" -ForegroundColor Green
}

# print colored `[ OK ]`
function printOK {
  Write-Host "    `t`t[ $e[92mOK$e[0m ]"
}

# print colored `[ NG ]`
function printNG {
  Write-Host "    `t`t[ $e[91mNG$e[0m ]"
}

# print colored `[ Restart required ]`
function printRestartRequired {
  Write-Host "    `t`t[ $e[93mRestart required$e[0m ]"
}

# takes a feature as parameter and enable it if needed
function checkAndEnableFeature ($featureName) {
  $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
  if (($null -ne $feature.FeatureName) -and ($feature.State -ne "Enabled")) {
    Write-Host "  └ Enabling" $feature.DisplayName "..." -NoNewline;
    $enabled = Enable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -All -NoRestart -WarningAction:SilentlyContinue
    if ($enabled.RestartNeeded) {
      $global:isRestartRequired = $true
      printRestartRequired
    } else {
      printOK
    }
  } elseif ($feature.State -eq "Enabled"){
    Write-Host "  └" $feature.DisplayName 'already enabled.' -NoNewline
    printOK
  }
}

# prints the big psbbn logo and the version number
function printTitle {
  Write-Host "
 ______  _________________ _   _  ______      __ _       _ _   _            ______          _           _   
 | ___ \/  ___| ___ \ ___ \ \ | | |  _  \    / _(_)     (_) | (_)           | ___ \        (_)         | |  
 | |_/ /\ `--. | |_/ / |_/ /  \| | | | | |___| |_ _ _ __  _| |_ ___   _____  | |_/ / __ ___  _  ___  ___| |_ 
 |  __/  `--. \  ___ \ ___ \ . `  | | | | / _ \  _| | '_ \| | __| \ \ / / _ \ |  __/ '__/ _ \| |/ _ \/ __| __|
 | |    /\__/ / |_/ / |_/ / |\  | | |/ /  __/ | | | | | | | |_| |\ V /  __/ | |  | | | (_) | |  __/ (__| |_ 
 \_|    \____/\____/\____/\_| \_/ |___/ \___|_| |_|_| |_|_|\__|_| \_/ \___| \_|  |_|  \___/| |\___|\___|\__|
                                                                                          _/ |              
                                                                                         |__/               

                                            Created by CosmicScale
                                                     ---
                                          Launcher for Windows v$version
                                               Written by Yornn

"
}

# display the available disks and prompt user for choice
function diskPicker {
  # store the current cursor position to help clear the console upon refreshing the list of disks
  $lineStart = $Host.UI.RawUI.CursorPosition.Y
  
  # verify that winwmgt is working properly
  winmgmt /verifyrepository

  # list available disks and pick the one to be mounted
  Write-Host "`nList of available disks:"
  try {
    $global:diskList = Get-Disk | Sort -Property Number
  }
  catch {
    Write-Host "
    ❌ The script failed to list the disks. This is often caused by corruption
    in the WMI repository. WebSearch '0x80041031,Get-Disk' to find solutions.
    " -ForegroundColor Red
    Exit
  }
  $disksExtras = detectDisksExtras
  $global:diskList | Format-Table -AutoSize -Property `
    Number, `
    @{Label="Name";Expression={$_.FriendlyName}}, `
    @{Label="Size";Expression={("{0:N2}" -f ($_.Size / 1GB)).ToString() + " GB"}}, `
    SerialNumber, `
    @{Label="";Expression={$disksExtras[$_.Number]}}
  
  if (($global:diskList | Where-Object -FilterScript {isTooSmall($_)}).Count -gt 0) {
    Write-Host "ℹ️ PSBBN requires a disk with a minimum capacity of 32 GB.`n" -ForegroundColor Yellow
  }

  $selectedDisk = handleDiskSelection

  if ($selectedDisk -eq "r") {
    clearLines($Host.UI.RawUI.CursorPosition.Y - $lineStart)
    diskPicker
  } else {
    $global:selectedDisk = $selectedDisk
  }
}

# handles the input logic of the diskpicker
# this function calls itself recursively as long an invalid input is provided
function handleDiskSelection {
  $selectedDisk = -1
  # generate a list of disk number to validate user input
  $availableNumbers = $global:diskList `
    | Where-Object -FilterScript {-Not (isTooSmall($_))} `
    | Foreach-Object {$_.Number}

  Write-Host "Select a disk to use with PSBBN by typing its number, or press `"r`" to refresh the list.`n"
  $promptMessage = " "
  $validInput = $false
  do {
    clearLines(1)
    $input = Read-Host "$promptMessage"
    $input = $input.ToLower()

    if (-Not $validInput) {
      $promptMessage = "$e[91mInvalid input, try again$e[0m"
    }

    # it is necessary to check if $input is empty first, or ($input -in $availableNumbers) will return true for some reason
    $validInput = $input -And (($input -in $availableNumbers) -Or ($input -eq "r"))
  } while (-Not $validInput)

  $selectedDisk = $input

  clearLines(1)
  Write-Host "Disk number $selectedDisk picked."

  return $selectedDisk
}

# detects if bios-level virtualization is enabled or not, and display messages
function detectVirtualization {
  Write-Host "Checking if virtualization is enabled in BIOS..." -NoNewline

  $propertyName = "HyperVRequirementVirtualizationFirmwareEnabled"
  $property = Get-ComputerInfo -property $propertyName

  # the property is null if the feature is enabled, false otherwise
  if ($property.$propertyName -eq $false) {
    printNG
    Write-Host "`n
    ⚠️ Virtualization is not enabled. It is mandatory to run PSBBN scripts.
    If you have an AMD CPU, enable SVM in your BIOS.
    If you have an Intel CPU, enable VT-x in your BIOS.
    Check the manual of your motherboard if you have troubles finding this setting.
    " -ForegroundColor Yellow
    Exit
  } else {
    printOK
  }
}

# set the disk offline and then mount it to WSL
# offline is necessary otherwise windows processes might prevent wsl from mounting
function mountDisk {
  $deviceName = "\\.\PHYSICALDRIVE$global:selectedDisk"
  Write-Host "`nMounting $deviceName on wsl...`t`t" -NoNewline
  $null = Set-Disk $global:selectedDisk -isOffline $true -errorAction SilentlyContinue
  $mountOut = wsl -d $wslLabel --mount $deviceName --bare
  handleMountOutput($mountOut)
}

# unmount the disk and then set the disk back online
function unmountDisk {
  $deviceName = "\\.\PHYSICALDRIVE$global:selectedDisk"
  Write-Host "Unmounting $deviceName...`t`t" -NoNewline
  $unmountOut = wsl -d $wslLabel --unmount $deviceName
  Set-Disk $global:selectedDisk -isOffline $false
  handleMountOutput($unmountOut)
}

# handles the error code returned by `wsl --mount` or wsl --unmount` and display human friendly messages
function handleMountOutput ($mountOut) {
  if ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/WSL_E_DISK_ALREADY_ATTACHED*") {
    # in the case where the disk was already attached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already mounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/DetachDisk/ERROR_FILE_NOT_FOUND*") {
    # in the case where the disk was already detached, we just carry on and treat it as a happy path
    printOK
    Write-Host "The disk was already unmounted." -ForegroundColor Green
    return
  } elseif ($mountOut -like "*Wsl/Service/AttachDisk/MountDisk/*0x8007000f*") {
    # attempting to mount a sdcard reader will return this error
    printNG
    Write-Host "❌ USB thumbdrives and SD card readers are not supported by the PSBBN Launcher for Windows." -ForegroundColor Red
    Exit
  } elseif ($mountOut -like "*Error code*") {
    printNG
    Write-Host $mountOut -ForegroundColor Red
    Exit
  }
  printOK
}

# checks if the script is running as admin, and if not launches itself in powershell instance running as admin
function restartAsAdminIfNeeded {
  if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # already running as admin, so we just carry on
    return
  }

  # if powershell 7 is installed, launch that one instead of 5.1
  $shell = "powershell"
  if (Get-Command pwsh -errorAction SilentlyContinue) {
    $shell = "pwsh"
  }

  # relaunch the script as admin, this should trigger a UAC prompt
  Start-Process $shell -Verb RunAs -ArgumentList "-NoLogo -NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""

  # close the initial non-admin shell to avoid confusion
  Exit
}

# handles the path picker and return a valid windows path as a string
function getTargetPath {
  # if a previously used path exists, use that in the folder picker, otherwise use "Desktop"
  $desktopDirectory = [Environment]::GetFolderPath('Desktop')
  $initialDirectory = $desktopDirectory
  $isPresetPath = $false
  if (Test-Path ".\$pathFilename" -PathType Leaf) {
    $initialDirectory = Get-Content -Path ".\$pathFilename"
    $isPresetPath = $true

    # check that the path in path.cfg still exists, if not default to "Desktop"
    if (-Not (Test-Path $initialDirectory -PathType Container)) {
      $initialDirectory = $desktopDirectory
      $isPresetPath = $false
    }
  }

  # if the path is already set, ask if the user wants to re-use it
  if ($isPresetPath) {
    Write-Host "`nThe following path was previously used: " -NoNewLine
    Write-Host "$initialDirectory`n" -ForegroundColor Green
    do {
      clearLines(1)
      $keyPressed = Read-Host "Would you like to keep using this path? (y/n)"
      $keyPressed = $keyPressed.ToLower()
    } while ($keyPressed -ne 'y' -and $keyPressed -ne 'n')

    if ($keyPressed -eq 'y') {
      preventsPickingWslPath($initialDirectory)
      return $initialDirectory
    }
  }

  Write-Host "`nNext, you'll be prompted to select or create a folder on your PC (for example, C:\PSBBN)." -ForegroundColor Yellow
  Write-Host "`nThis folder is for all the games, music, videos, and image files you plan to install." -ForegroundColor Yellow

  pause

  # prepare and then open the folder picker
  Add-Type -AssemblyName System.Windows.Forms
  $pathSelection = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = $initialDirectory
    CheckFileExists = 0
    ValidateNames = 0
    FileName = "Choose Folder"
  }
  $result = $pathSelection.ShowDialog()

  if($result -ne "OK") {
    Write-Host "No folder was picked, you will have to do it manually later." -ForegroundColor Yellow
    return ""
  }

  $pickedPath = Split-Path -Parent $pathSelection.FileName

  preventsPickingWslPath($pickedPath)

  # create default folders if missing
  $defaultFolders.ForEach({
    if (-Not (Test-Path -Path "$pickedPath\$PSItem")) {
      New-Item -Path $pickedPath -Name $PSItem -ItemType Directory | Out-Null
    }
  })

  Write-Host "`nThe following path was chosen: $pickedPath" -ForegroundColor Green
  Write-Host "
Before you continue, you can fill this folder with your games and other media:
    - put PS2 DVD games in /DVD (.iso or .zso files)
    - put PS2 CD games in /CD (.bin & .cue, .iso or .zso files)
    - put PS1 games in /POPS (.bin & .cue or .vcd files)
    - put homebrew in /APPS (.elf or SAS-compliant .psu files)
    - put music in /music (.mp3, .m4a, .flac, or .ogg files)
    - put videos in /movie (.mp4, .m4v, .mkv, .vob, .mpg files, etc)
    - put images in /photo (.jpg, .png, .tif, .gif, .bmp, .webp files, etc)

You can refer to the PSBBN Readme to know more.
https://github.com/CosmicScale/PSBBN-Definitive-Project
" -ForegroundColor Yellow

  # store the selected path to re-use next time the script is ran
  New-Item -Path "." -Name $pathFilename -ItemType "file" -Value $pickedPath -Force | Out-Null

  return $pickedPath
}

# clears $count lines with spaces and move the cursor back
function clearLines ($count) {
  $currentLine  = $Host.UI.RawUI.CursorPosition.Y
  $consoleWidth = $Host.UI.RawUI.BufferSize.Width

  $i = 0
  for ($i; $i -le $count; $i++) {
      [Console]::SetCursorPosition(0,($currentLine - $i))
      [Console]::Write("{0,-$consoleWidth}" -f " ")
  }
  [Console]::SetCursorPosition(0,($CurrentLine - $count))
}

# for each disk, generate a message to be displayed in the diskPicker list's last column
function detectDisksExtras {
  # a keyed array of <(int) diskNumber, (string) messages>
  $messages = @{}

  $global:diskList | ForEach-Object {
    $message = "   "
    $diskNumber = $_.Number

    # walks through each partition -> volume to find which disks have volumes named $oplVolumeName
    $null = Get-Partition -disknumber $diskNumber -errorAction SilentlyContinue | ForEach-Object {
      Get-Volume -partition $_ | ForEach-Object {
        $_.FileSystemLabel.GetType()
        if ($_.FileSystemLabel -eq $oplVolumeName) {
          $message = "$e[92mPSBBN detected$e[0m"
        }
      }
    }

    # PSBBN requires disk with at least 32 GB
    if (isTooSmall($_)) {
      $message = "$e[91mInsufficient size$e[0m"
    }

    $messages.Add($diskNumber, $message)
  }

  return $messages
}

function isTooSmall ($item) {
  return ($item.Size / 1GB) -lt $minimumDiskSize
}

function prepareWslPath ($windowsPath) {
  $wslPath = ''
  
  # covers basic drive letters
  if ($windowsPath -match '(?<driveLetter>.):\\(?<path>.+)?') {
    $driveLetter = $Matches.driveLetter.ToLower()
    $path = ""
    if ($Matches.path) {
      $path = $Matches.path.Replace("\", "/")
    }
    $wslPath = "/mnt/$driveLetter/$path"
  }
  # covers network paths (e.g. samba drives)
  elseif ($windowsPath -match '\\\\(?<host>[0-9a-zA-Z._-]+)\\(?<path>.+)') {
    $wslPath = $networkDriveMountpoint
    
    # network drives are not mounted by default, so manually mount the selected path
    Write-Host "A network drive location was selected, so it needs to be mounted. You will be asked for your linux password." -ForegroundColor Yellow
    wsl -d $wslLabel --cd "~" -- mountpoint -q $networkDriveMountpoint `|`| `( `
      sudo mkdir $networkDriveMountpoint `&`> /dev/null `; `
      sudo mount -t drvfs `'$windowsPath`' $networkDriveMountpoint `
    `)
    $global:isDriveMounted = $true
    Write-Host "Network drive mounted.`t`t" -NoNewLine
    printOK
  }

  return $wslPath
}

function unmountTargetPath {
  if ($global:isDriveMounted) {
    Write-Host "The network drive location needs to be unmounted. You will be asked for your linux password." -ForegroundColor Yellow
    wsl -d $wslLabel --cd "~" -- sudo umount $networkDriveMountpoint
    $global:isDriveMounted = $false
    Write-Host "Network drive unmounted.`t`t" -NoNewLine
    printOK
  }
}

# prevents the user from picking a wsl filesystem location
function preventsPickingWslPath ($path) {
  if ($path -like '\\wsl.localhost\*') {
    unmountDisk
    Write-Host "
    ⚠️ You should not store your files on the linux filesystem, as it can easily be deleted.
    Create a folder on your windows disk, move your isos and others files there.
    Once done, you can re-run this script and pick that new folder.
    " -ForegroundColor Yellow
    Exit
  }
}

restartAsAdminIfNeeded

# necessary to ensure the CWD is where the script is located, in case the script was restarted as admin
cd $PSScriptRoot

if ($LogsEnabled) {
  try { $null = Start-Transcript -Path ".\psbbn-windows-launcher.log" }  catch {}
  try {
    main
  } finally {
    try { $null = Stop-Transcript } catch {}
  }
} else {
  main
}
