# Todo:
# Create module manifest (.psd1)
# Try to find a way of getting some kind of CPU compatibility information.
# Need to tidy up variable names and follow some kind of convention and scoping.
# Learn how to keep function parameters private (or not) and whether to pass an object or text is the right thing to do.
#   https://stackoverflow.com/questions/27847809/in-powershell-how-to-set-variable-values-within-a-function-and-have-that-value
# Add module versioning.
# Output each VMDK size + this total.  Capacity has many contributing factors so is worth reporting from many different points of view.
# Export a notes tab in the results explaining each column.

function Get-RJVMMetaData {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        A function to collect metadata from a specified VM.

    .DESCRIPTION
        The function returns an array object containing the VM's Tags and attributes.

    .EXAMPLE
        $VMData = Get-RJVMMetaData -VMName "TheServer"
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    Begin {}

    Process {
        $Private:oVMGuest = Get-VM -Name $VMName
        $Private:VCServer = $oVMGuest.Uid.Split(":")[0].Split("@")[1]
        $Private:CustomAttrList = Get-CustomAttribute -Server $oVMGuest.Uid.Split(":")[0].Split("@")[1]
        $Private:OutputCustomAttrKey = @()
        $Private:OutputCustomAttrName = @()
        $Private:OutputCustomAttrValue = @()
        $Private:LocationCodeC = $Null
        $Private:LocationCodeH = $Null
        $Private:LocationCode = $Null
        $Private:CustomAttributes = $oVMGuest.ExtensionData.CustomValue
        $Private:CustomAttribute = $Null
        $Private:HardDisks = Get-HardDisk -VM $oVMGuest
        $Private:LocalHardDisks = (((Get-VMGuest -VM $ovmguest).disks | select-object Path, CapacityGB, FreespaceGB) | sort-object path)
        $Private:HardDisk = $Null
        $Private:LocalHardDisk = $Null
        $Private:OutputDiskDatastore = @()
        $Private:OutputLocalDiskSize = $Null
        $Private:OutputObject = New-Object -TypeName PSObject

        If ($oVMGuest) {
            $OutputObject | Add-Member -Name "Name" -MemberType NoteProperty -value $oVMGuest.name
            $OutputObject | Add-Member -Name "ID" -MemberType NoteProperty -value $oVMGuest.id
            $OutputObject | Add-Member -Name "HostName" -MemberType NoteProperty -value $oVMGuest.VMHost.Name
            $OutputObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $oVMGuest.powerstate 
            $OutputObject | Add-Member -Name "Version" -MemberType NoteProperty -value $oVMGuest.ExtensionData.Config.Version 
            $OutputObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $oVMGuest.memorygb 
            $OutputObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $oVMGuest.NumCpu
            $OutputObject | Add-member -Name "TotalDiskSizeGB" -MemberType NoteProperty -Value (ForEach-object { (Get-HardDisk -VM $oVMGuest | Measure-Object -Property CapacityGB -Sum).sum })
            $OutputObject | Add-Member -Name "UsedSpaceGB" -MemberType NoteProperty -value $oVMGuest.UsedSpaceGB
            $OutputObject | Add-Member -Name "ProvisionedSpaceGB" -MemberType NoteProperty -value $oVMGuest.ProvisionedSpaceGB
            $OutputObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $oVMGuest.ExtensionData.Guest.ToolsVersion 
            $OutputObject | Add-Member -Name "GuestFullName" -MemberType NoteProperty -value $oVMGuest.ExtensionData.Guest.GuestFullName 
            $OutputObject | Add-Member -Name "CreateDate" -MemberType NoteProperty -value $oVMGuest.ExtensionData.Config.CreateDate 
            $OutputObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $VCServer
            $OutputObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value (get-vmhost -vm $oVMGuest).version 
            $OutputObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value (get-vmhost -vm $oVMGuest).build 
            $OutputObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value (Get-Datacenter -Server $VCServer -vm $oVMGuest.name) 
            $OutputObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -Server $VCServer -vm $oVMGuest.name) 
            $OutputObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value (Get-ResourcePool -Server $VCServer -VM $oVMGuest) 
            $OutputObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $oVMGuest.Folder
            $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $oVMGuest.Notes
            $OutputObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value ($oVMGuest | get-snapshot).Created 
            
            ForEach ($CustomAttribute in $CustomAttributes) {
                If ($CustomAttribute.Value) {
                    $outputCustomAttrKey += $CustomAttribute.key
                    $outputCustomAttrName += ($CustomAttrList | where-object { $_.Key -eq $CustomAttribute.Key }).Name
                    $outputCustomAttrValue += $CustomAttribute.value
                }
            }
            
            $LocationCodeC = ((Get-Cluster -vm $oVMGuest.name).ExtensionData.CustomValue | where-object { $_.key -eq (($CustomAttrList | where-object { $_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster' }).key) }).value
            $LocationCodeH = ((Get-VMHost -vm $oVMGuest.name).ExtensionData.CustomValue | where-object { $_.key -eq (($CustomAttrList | where-object { $_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost' }).key) }).value

            If ($LocationCodeC) {
                $LocationCode = $LocationCodeC
            }
            else {
                $LocationCode = $LocationCodeH
            }

            $OutputObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode
            $OutputObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $outputCustomAttrName
            $OutputObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $outputCustomAttrValue
            $OutputObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value (Get-TagAssignment -Entity $oVMGuest).Tag.Name

            ForEach ($HardDisk in $HardDisks) { $OutputDiskDatastore += ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value }
            ForEach ($LocalHardDisk in $LocalHardDisks) {
                $OutputLocalDiskSize += ($LocalHardDisk.CapacityGB - $LocalHardDisk.FreeSpaceGB)
            }

            If ($Null -eq $OutputLocalDiskSize -or $OutputLocalDiskSize -eq 0) { $OutputLocalDiskSize = $oVMGuest.ProvisionedSpaceGB }

            $OutputObject | Add-Member -Name "LocalHardDisksPath" -MemberType NoteProperty -value $LocalHardDisks.path
            $OutputObject | Add-Member -Name "LocalHardDisksCapacityGB" -MemberType NoteProperty -value $LocalHardDisks.CapacityGB
            $OutputObject | Add-Member -Name "LocalHardDisksFreespaceGB" -MemberType NoteProperty -value $LocalHardDisks.FreespaceGB
            $OutputObject | Add-Member -Name "LocalHardDiskTotalGB" -MemberType NoteProperty -value $OutputLocalDiskSize
            $OutputObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value (Get-NetworkAdapter -VM $oVMGuest).NetworkName
            $OutputObject | Add-Member -Name "DiskLayoutStorageFormat" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).StorageFormat
            $OutputObject | Add-Member -Name "DiskLayoutPersistence" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).Persistence
            $OutputObject | Add-Member -Name "DiskLayoutDiskType" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).DiskType
            $OutputObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $outputDiskDatastore
            $OutputObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).Name
            $OutputObject | Add-Member -Name "DiskID" -MemberType NoteProperty -value (Get-SpbmEntityConfiguration -HardDisk (Get-HardDisk -VM $oVMGuest)).id
            $OutputObject | Add-Member -Name "DiskStoragePolicy" -MemberType NoteProperty -value (Get-SpbmEntityConfiguration -HardDisk (Get-HardDisk -VM $oVMGuest)).StoragePolicy.Name
            $OutputObject | Add-Member -Name "DiskFileName" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).Filename
            $OutputObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).CapacityGB

            return $OutputObject
        }
    }

    End {}
}

function Get-RJVMHostData {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        A function to return the key network and datastore data necessary for a Cross vCenter VM Migration.

    .DESCRIPTION
        Returns an array containing a specific host's available Datastore, Port Groups and Switches.

    .EXAMPLE
        $TheHost = Get-RJVMHostData -VMHost "TheVMHost"
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [string]$VMHost
    )

    Begin {}

    Process {
        $Private:oVMHost = Get-VMhost -name $VMHost
        $Private:VCServer = $oVMHost.Uid.Split(":")[0].Split("@")[1]
        $Private:CustomAttrList = Get-CustomAttribute -Server $oVMHost.Uid.Split(":")[0].Split("@")[1]
        $Private:Datastores = get-datastore -vmhost $oVMHost   
        $Private:Datastore = $Null
        $Private:LocationCodeC = $Null
        $Private:LocationCodeH = $Null
        $Private:LocationCode = $Null
        $Private:OutputObject = New-Object -TypeName PSObject

        If ($oVMHost) {
            $OutputObject | Add-Member -Name "Name" -MemberType NoteProperty -value $oVMHost.Name
            $OutputObject | Add-Member -Name "ConnectionState" -MemberType NoteProperty -value $oVMHost.ConnectionState
            $OutputObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $VCServer
            $OutputObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -vmhost $oVMHost) 
            $OutputObject | Add-Member -Name "Vendor" -MemberType NoteProperty -value $oVMHost.ExtensionData.Hardware.SystemInfo.Vendor
            $OutputObject | Add-Member -Name "Model" -MemberType NoteProperty -value $oVMHost.ExtensionData.Hardware.SystemInfo.Model
            
            If ($oVMHost.ConnectionState -ne "NotResponding") {
                Try { $OutputObject | Add-Member -Name "EncryptionMode" -MemberType NoteProperty -Value ($oVMHost | Get-EsxCli -v2).System.Settings.Encryption.Get.Invoke().Mode | Out-Null } Catch {}
                Try { $OutputObject | Add-Member -Name "RequireSecureBoot" -MemberType NoteProperty -Value ($oVMHost | Get-EsxCli -v2).System.Settings.Encryption.Get.Invoke().RequireSecureBoot | Out-Null } Catch {}
                Try { $OutputObject | Add-Member -Name "EncryptionRecoveryID" -MemberType NoteProperty -value ($oVMHost | Get-EsxCli -v2).System.Settings.Encryption.Recovery.List.Invoke().RecoveryId | Out-Null } Catch {}
                Try { $OutputObject | Add-Member -Name "EncryptionRecoveryKey" -MemberType NoteProperty -value ($oVMHost | Get-EsxCli -v2).System.Settings.Encryption.Recovery.List.Invoke().Key | Out-Null } Catch {}
                Try { $OutputObject | Add-Member -Name "SerialNumber" -MemberType NoteProperty -value ($oVMHost | Get-EsxCli -V2).Hardware.Platform.Get.Invoke().Enclosureserialnumber | Out-Null }  Catch {}
                Try { $OutputObject | Add-Member -Name "IPMIIP" -MemberType NoteProperty -value ($oVMHost | Get-esxCli -V2).Hardware.Ipmi.Bmc.Get.Invoke().Ipv4Address | Out-Null } Catch {}
            }

            $OutputObject | Add-Member -Name "LicenseKey" -MemberType NoteProperty -value $oVMHost.LicenseKey
            $OutputObject | Add-Member -Name "NumCpu" -MemberType NoteProperty -value $oVMHost.NumCpu
            $OutputObject | Add-Member -Name "CryptoState" -MemberType NoteProperty -value $oVMHost.CryptoState
            $OutputObject | Add-Member -Name "Version" -MemberType NoteProperty -value $oVMHost.Version
            $OutputObject | Add-Member -Name "Build" -MemberType NoteProperty -value $oVMHost.Build
            $OutputObject | Add-Member -Name "MemoryTotalGB" -MemberType NoteProperty -value ([math]::Round($oVMHost.MemoryTotalGB, 0))
            $OutputObject | Add-Member -Name "MaxEVCMode" -MemberType NoteProperty -value $oVMHost.MaxEVCMode
            $OutputObject | Add-Member -Name "ProcessorType" -MemberType NoteProperty -value $oVMHost.ProcessorType

            $LocationCodeC = ((Get-Cluster -vmhost $ovmhost.name).ExtensionData.customvalue | where-object { $_.key -eq (($CustomAttrList | where-object { $_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster' }).key) }).value
            $LocationCodeH = ((Get-VMHost -name $ovmhost.name).ExtensionData.customvalue | where-object { $_.key -eq (($CustomAttrList | where-object { $_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost' }).key) }).value

            If ($LocationCodeC) {
                $LocationCode = $LocationCodeC
            }
            else {
                $LocationCode = $LocationCodeH
            }

            $OutputObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode

            If ($Datastores) {
                $OutputObject | Add-Member -Name "DatastoreName" -MemberType NoteProperty -value $Datastores.Name
                $OutputObject | Add-Member -Name "DatastoreType" -MemberType NoteProperty -value $Datastores.Type
                $OutputObject | Add-Member -Name "DatastoreCapacityGB" -MemberType NoteProperty -value $Datastores.CapacityGB
            }

            If (($oVMHost.extensiondata.hardware.systeminfo.Model).Substring(0, 6) -eq 'vxrail') {
                ForEach ($Datastore in $Datastores) {
                    If ($Datastore.Name.Substring(0, 2) -eq 'DE') {
                        $OutputObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $Datastore.Name.Substring(0, 14)
                    }
                }
            }
            else {
                $OutputObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $Null
            }

            $OutputObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value (Get-VirtualPortGroup -vmhost $oVMHost).name
            $OutputObject | Add-Member -Name "NetworkSwitch" -MemberType NoteProperty -value (Get-Virtualswitch -vmhost $oVMHost).name

            return $OutputObject
        }
    }

    End {}
}

# what is the difference between and [object] and a [psobject].
# should I be passing objects or just the text?
function Set-RJVMCustomAttributes {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        A function to import the tags and custom attributes for a specified VM based on the export from a previous Get-RJVMMetaData call.
    .DESCRIPTION
        More of what it does.
    .EXAMPLE
        Set-RJVMCustomAttributes -VMName $VMtoMove -TargetVM $TargetVM -TargetVC $TargetVC -VMMetaDataItems $VMMetaDataItems
    #>

    param (
        [Parameter(Mandatory = $true)]
        [psobject]$TargetVM,
        [Parameter(Mandatory = $true)]
        [psobject]$TargetVC,
        [Parameter(Mandatory = $true)]
        [psobject]$VMMetaData
    )

    Begin {}

    Process {
        $Private:AllCustomAttributeName = $VMMetaData.AttributeName
        $Private:AllCustomAttributeValue = $VMMetaData.AttributeValue
        $Private:AllCustomAttributeTag = $VMMetaData.AttributeTag
        $Private:CustomAttributeName 
        $Private:CustomAttributeTag
        $Private:AttributeCount = 0

        If ($AllCustomAttributeName) {
            ForEach ($CustomAttributeName in $AllCustomAttributeName) {
                $TargetVM | Set-Annotation -CustomAttribute $CustomAttributeName -Value $AllCustomAttributeValue[$AttributeCount] | Out-Null
                $AttributeCount++
            }
        }

        If ($AllCustomAttributeTag) {
            ForEach ($CustomAttributeTag in $AllCustomAttributeTag) {
                New-TagAssignment -Tag $CustomAttributeTag -Entity $TargetVM -Server $TargetVC | Out-Null
            }
        }
    }
    End {}
}

function Write-RJLog {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        A function to write a timestamped log entry to a specified file.
    .DESCRIPTION
        More of what it does.
    .EXAMPLE
        Write-RJLog -LogFile <Fileobject> -Severity <0..3> -LogText <Log Text>
    #>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$LogFile,
        [Parameter(Position = 1)]
        [ValidateRange(0, 3)]
        [int]$Severity = 0,
        [Parameter(Position = 2)]
        [string]$LogText = "--------------------------------------------------------------------------"
    )

    Begin {}

    Process {
        $Private:LogOutput = (get-date -format "yyyy/MM/dd HH:mm:ss | ")
        If ($Severity -eq 0) { $LogOutput += "INFO  | " }
        If ($Severity -eq 1) { $LogOutput += "DEBUG | " }
        If ($Severity -eq 2) { $LogOutput += "WARN  | " }
        If ($Severity -eq 3) { $LogOutput += "CRIT  | " }

        add-content $LogFile $LogOutput$LogText
        write-host $LogOutput$LogText
    }

    End {}
}