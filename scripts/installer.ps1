# Install for Weasel
# Copyright (C) 2023  Xuesong Peng <pengxuesong.cn@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

<#
.SYNOPSIS
    Rime schema installer
.DESCRIPTION
    Install schemas of user schemas
.PARAMETER Proxy
    The Uri of proxy server
.LINK
    https://github.com/amorphobia/rime-user-config
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Proxy
)

function Get-RimeUserDir {
    $dir = ""
    $registry_root = "HKCU:\SOFTWARE\Rime\Weasel"
    if (Test-Path -Path $registry_root) {
        $dir = (Get-ItemProperty -Path $registry_root).RimeUserDir
    }
    if (!$dir) {
        $dir = "$Env:APPDATA\Rime"
    }

    return $dir
}

function Get-DownloadUrl {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Proxy
    )
    $p = if ($Proxy) { @{ Proxy = $Proxy } } else { @{} }

    $query_url = "https://api.github.com/repos/amorphobia/rime-user-config/releases/latest"
    $tag = (Invoke-RestMethod @p $query_url).tag_name
    $zip = "weasel-$tag.zip"

    return "https://github.com/amorphobia/rime-user-config/releases/download/$tag/$zip"
}

function Start-Deployment {
    $dir = ""
    $registry_root = "HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel"
    if (Test-Path -Path $registry_root) {
        $dir = (Get-ItemProperty -Path $registry_root).WeaselRoot
    }
    if ($dir -and (Test-Path "$dir\WeaselDeployer.exe")) {
        & "$dir\WeaselDeployer.exe" /deploy
    }
}

$p = if ($Proxy) { @{ Proxy = $Proxy } } else { @{} }

$download_url = Get-DownloadUrl @p
$tmp = New-TemporaryFile
$zip = Move-Item -Path (Convert-Path $tmp.PSPath) -Destination ((Convert-Path $tmp.PSParentPath) + "\" + ([uri]$download_url).Segments[-1]) -PassThru -Force
$dest_path = "$env:TEMP\" + [io.path]::GetFileNameWithoutExtension($zip)

Write-Host "Downloading latest schemas & config ..."
Invoke-WebRequest @p $download_url -Out $zip

Write-Host "Expanding zip archive ..."
Expand-Archive -Path $zip -DestinationPath $dest_path -Force

Remove-Item "$dest_path\jiandao.user.dict.yaml"

$rime_user_dir = Get-RimeUserDir

Write-Host "Copying files to rime user data directory ..."
Copy-Item -Force -Recurse "$dest_path\*" "$rime_user_dir\"

Write-Host "Start Weasel deployment."
Start-Deployment

Write-Host "Cleaning up downloaded fimes ..."
Remove-Item -Recurse -Force $zip
Remove-Item -Recurse -Force $dest_path
