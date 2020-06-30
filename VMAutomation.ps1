$Server = 'secretServer'
$secpasswd = ConvertTo-SecureString $env:VMpassword -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($env:VMusername, $secpasswd)

#Location for the script to log to
$log="C:\windows\config\logs\imaging.log"
$Namespath="listOfUsedVMNames"
function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path=$log,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",

        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {

        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            New-Item $Path -Force -ItemType File
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }

        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}

if (!($VCenter))
{
    $Script:VCenter= $Server
    Connect-VIServer $VCenter -credential $mycreds
}
Function Get-Name
{
   param
   (
       [Parameter(Mandatory=$true)]
       [String]$imagename
   )
    $path="listOfUsedVMNames"
    $NamesInCsv=(Import-Csv $path | select name).name
    Write-Log -Message "Gathering used PVM names"
    $TakenNames=get-vm -name $imagename*

    for ($i = 1; $i -le 9999; $i++)
    {
        Switch ($i.tostring().Length)
        {
            1 {$PVMName=$imagename + '000' +$i}
            2 {$PVMName=$imagename + '00' +$i}
            3 {$PVMName=$imagename + 0 + $i}
            4 {$PVMName=$imagename + $i}
        }

        if ($NamesInCsv -notcontains $PVMName)
          {
            $filter='Name -like "{0}"' -f $PVMName
              if ( (!(Get-ADComputer -Filter $filter)) -and $TakenNames -notcontains $PVMName )
                  {
                      $Script:VMName=$PVMName
                      Write-Log -Message "$VMName isn't in use, I'll select that as the name for our new VM"
                      break
                  }
                  else
                  {
                      $NewLine = "{0},{1},{2},{3}" -f $PVMName, 'ADDED BY SCRIPT', 'ADDED BY SCRIPT','ADDED BY SCRIPT'
                      $NewLine | add-content -path $NamesPath
                  }
        }
    }
}
function New-VSVM {

    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Computername,
        [string]$Template,
        [string]$DataStore,
        [string]$NetworkName = 'Internal1',
        [string]$LiteTouchPath,
        [string]$VMHost,
        [string]$VCenter,
        [string]$Isostore,
        [string]$Location,
        [string]$DiskStorageFormat

    )

        New-VM -Name $computername -VMHost $VMHost -Template $Template -Datastore $Datastore -Location $Location -DiskStorageFormat $DiskStorageFormat
        Get-VM -Name $ComputerName | Get-CDDrive | Set-CDDrive -IsoPath "[$Isostore] $ISO"  -Confirm:$false -StartConnected:$true
        Start-VM -VM $ComputerName -Confirm:$False
        Start-Sleep -Seconds 60
        Get-CDDrive -VM $ComputerName | Set-CDDrive -NoMedia -Confirm:$False

    }


    for ($i = 1; $i -le $env:quantity; $i++)
    {
        Get-Name -imagename PVM
        "VM name is $VMName"
        $Folder = Get-Folder "secretFolder"
        $Network ='secretNetwork'
        $VMHost = Get-Cluster -Name 'secretCluster' | Get-VMHost | Get-Random
        $Template = Get-Template "secretTemplate"
        Connect-VIServer -server "secretServer" -credential $mycreds -Force
        $isostore = "secretIsostore"
        $ISO = "secretIso"

        New-VSVM -VCenter $VCenter -Computername $Script:VMName -DataStore 'secretDatastore' -VMHost $VMHost -Template $Template -Isostore $isostore  -LiteTouchPath $ISO -Location $Folder -DiskStorageFormat Thin -NetworkName $Network
    }