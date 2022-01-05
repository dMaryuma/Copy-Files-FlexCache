
try{Import-Module dataontap; Write-Host "import module DataONTAP successfully"}catch{Write-Host $_; exit(1)}

# create log in format "scriptname_date"
$logpath = "C:\CopyFiles\log"
try{$logfile = New-Item -Path $logpath -Name "$($MyInvocation.MyCommand.Name)_$(get-date -Format yyyy.MM.dd_HH.mm.ss).log"}catch{Write-Host $_; exit(1)}
Function LogWrite
{
   Param ([string]$logstring)
   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
   Add-content $Logfile -value "$Stamp -- $logstring"
}

################ MAIN ###################
# params
$userName = 'admin'
$userPassword = 'Netapp1!'| ConvertTo-SecureString -AsPlainText -Force
[pscredential]$cred = New-Object System.Management.Automation.PSCredential ($userName, $userPassword)
try{
    Connect-NcController 192.168.0.101 -Credential $cred -ea stop
    }catch{Write-Host $_; exit(1)}
$originPath = "src"
$destinationPath = "dst"
$originVolume = "vol1"
$originVserver = "svm1"
$fileFlag = ".f"
$fileExt = ".exe"

while ($true){
    $vol = get-ncvol -name $originVolume -Vserver $originVserver

    # list of files under $originPath directory
    $volFiles = Read-NcDirectory -Path "/vol/$originVolume/$originPath" -VserverContext $originVserver | ?{$_.Type -like "file"}
    # copy files to $destinationPath only if file.flag exist, then delete the
    # e.g copy "file1.exe" if "file1.flag" exist

    foreach ($file in $volFiles){
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $fileExtention = [System.IO.Path]::GetExtension($file.Name)

        # if file.flag selected first, continue search
        if ($fileExtention -like $fileFlag){continue}

        # try getting file with flag extention
        try{
            $fileWithExtention = Get-NcFile -Path "/vol/$originVolume/$originPath/$($fileName)$fileFlag" -VserverContext $originVserver -ErrorAction Stop
        }catch {if ($_ -like "*No such file or directory*"){
            Write-Host "No extention file exist for path /vol/$originVolume/$originPath/$($file.name), Continue... ";
            LogWrite -logstring "No extention file exist for path /vol/$originVolume/$originPath/$($file.name), Continue... ";
            Continue}else{Write-Host $_}
        }
        # if file with extention found:
        if ($fileWithExtention){
            # copy file and fileExt to destination dir
            try{
                New-NcClone -SourcePath "$originPath/$($file.name)" -DestinationPath "$destinationPath/$($file.name)" -VserverContext $originVserver -Volume $vol.Name -ErrorAction stop
                LogWrite "Copy file $originPath/$($file.name) to $destinationPath/$($file.name)"
                Write-Host "Copy file $originPath/$($file.name) to $destinationPath/$($file.name)"
                New-NcClone -SourcePath "$originPath/$($fileWithExtention.Name)" -DestinationPath "$destinationPath/$($fileWithExtention.Name)" -VserverContext $originVserver -Volume $vol.Name -ErrorAction stop
                LogWrite "Copy file $originPath/$($fileWithExtention.Name) to $destinationPath/$($fileWithExtention.Name)"
                Write-Host "Copy file $originPath/$($fileWithExtention.Name) to $destinationPath/$($fileWithExtention.Name)"

            }catch { if ($_ -like "*Clone file exists*"){}else{
                Write-Host "ERROR on path: $originPath/$($file.name) $_";
                LogWrite "ERROR on path: $originPath/$($file.name) $_"}
            }
                
            # delete file.$fileFlag so next time the file will no be copy
            try{
                Remove-NcFile -Path "/vol/$originVolume/$originPath/$($fileWithExtention.Name)" -VserverContext $originVserver -Confirm:$false -ErrorAction stop 
            }catch{
                LogWrite $_
                Write-Host $_;Continue
            }
        }
    }
    # sleep for x seconds before trying again looking for files under OriginFolders
    Start-Sleep 2
}
