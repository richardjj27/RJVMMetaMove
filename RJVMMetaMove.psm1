# Todo:
# Create module manifest (.psd1)
# Learn how to keep function parameters private (or not) and whether to pass an object or text is the right thing to do.
# Try to find a way of getting some kind of CPU compatibility information.
# Need to tidy up variable names and follow some kind of convention and scoping.
#   https://stackoverflow.com/questions/27847809/in-powershell-how-to-set-variable-values-within-a-function-and-have-that-value
# Add module version/ing.
# Put some logging in place with error checking.
# Writing of tag/attributes writes to console.
# Try to freeze first column in export scripts. - now using -FreezeTopRowFirstColumn - need to test
# Rreturns the correct cluster (and null if not in onee) - done but need to test.
# [CmdletBinding()] - done but need to test.

function Get-RJVMMetaData {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        A function to collect metadata from a spefified VM.

    .DESCRIPTION
        The function returns an array object containing the VM's Tags and attributes.

    .EXAMPLE
        $VMData = Get-RJVMMetaData -VMName "TheBigServer"
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$VMName
    )
    
    Begin{}

    Process{
        $Private:oVMGuest = Get-VM -Name $VMName
        $Private:VCServer = $oVMGuest.Uid.Split(":")[0].Split("@")[1]
        $Private:CustomAttrList = Get-CustomAttribute -Server $oVMGuest.Uid.Split(":")[0].Split("@")[1]
        $Private:outputCustomAttrKey = @()
        $Private:outputCustomAttrName = @()
        $Private:outputCustomAttrValue = @()
        $Private:LocationCodeC = $null
        $Private:LocationCodeH = $null
        $Private:LocationCode = $null
        $Private:CustomAttributes = $oVMGuest.ExtensionData.CustomValue
        $Private:CustomAttribute = $null
        $Private:HardDisks = get-HardDisk -VM $oVMGuest
        $Private:HardDisk = $null
        $Private:OutputDiskDatastore = @()
        $Private:OutputObject = New-Object -TypeName PSObject

        If ($oVMGuest) {
            $OutputObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $oVMGuest.name
            $OutputObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $oVMGuest.powerstate 
            $OutputObject | Add-Member -Name "VMVersion" -MemberType NoteProperty -value $oVMGuest.extensiondata.config.version 
            $OutputObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $oVMGuest.memorygb 
            $OutputObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $oVMGuest.NumCpu 
            $OutputObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $oVMGuest.extensiondata.guest.toolsversion 
            $OutputObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $oVMGuest.extensiondata.guest.guestfullname 
            $OutputObject | Add-Member -Name "VMCreated" -MemberType NoteProperty -value $oVMGuest.extensiondata.config.createdate 
            $OutputObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $VCServer
            $OutputObject | Add-Member -Name "Host" -MemberType NoteProperty -value (get-vmhost -vm $oVMGuest).name 
            $OutputObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value (get-vmhost -vm $oVMGuest).version 
            $OutputObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value (get-vmhost -vm $oVMGuest).build 
            $OutputObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value (Get-Datacenter -Server $VCServer -vm $oVMGuest.name) 
            $OutputObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -Server $VCServer -vm $oVMGuest.name) 
            $OutputObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value (Get-ResourcePool -Server $VCServer -VM $oVMGuest) 
            $OutputObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $oVMGuest.folder 
            $OutputObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $oVMGuest.notes
            $OutputObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value ($oVMGuest | get-snapshot).created 
            
            foreach ($CustomAttribute in $CustomAttributes) {
                if ($CustomAttribute.Value) {
                    $outputCustomAttrKey += $CustomAttribute.key
                    $outputCustomAttrName += ($CustomAttrList | where-object {$_.Key -eq $CustomAttribute.Key}).Name
                    $outputCustomAttrValue += $CustomAttribute.value
                }
            }
            
            $LocationCodeC = ((Get-Cluster -vm $oVMGuest.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster'}).key)}).value
            $LocationCodeH = ((Get-VMHost -vm $oVMGuest.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost'}).key)}).value

            if ($LocationCodeC){
                $LocationCode = $LocationCodeC
            }
            else {
                $LocationCode = $LocationCodeH
            }

            $OutputObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode
            $OutputObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $outputCustomAttrName
            $OutputObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $outputCustomAttrValue
            $OutputObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value (Get-TagAssignment -Entity $oVMGuest).Tag.Name

            foreach ($HardDisk in $HardDisks) {
                $OutputDiskDatastore += ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value
            }

            $OutputObject | Add-Member -Name "Network" -MemberType NoteProperty -value (Get-NetworkAdapter -VM $oVMGuest).NetworkName
            $OutputObject | Add-Member -Name "DiskLayoutStorageFormat" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).StorageFormat
            $OutputObject | Add-Member -Name "DiskLayoutPersistence" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).Persistence
            $OutputObject | Add-Member -Name "DiskLayoutDiskType" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).DiskType
            $OutputObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $outputDiskDatastore
            $OutputObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).Name
            $OutputObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value (get-HardDisk -VM $oVMGuest).CapacityGB

            return $OutputObject
        }

        else {
            Write-Error "Virtual machine not found."
            return $null
        }
    }

    End{}
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

    Begin{}

    Process{
        $Private:oVMHost = get-vmhost -name $VMHost
        $Private:VCServer = $oVMHost.Uid.Split(":")[0].Split("@")[1]
        $Private:CustomAttrList = Get-CustomAttribute -Server $oVMHost.Uid.Split(":")[0].Split("@")[1]
        $Private:Datastores = get-datastore -vmhost $oVMHost   
        $Private:Datastore = $null
        $Private:LocationCodeC = $null
        $Private:LocationCodeH = $null
        $Private:LocationCode = $null
        $Private:OutputObject = New-Object -TypeName PSObject

        if($oVMHost){
            $OutputObject | Add-Member -Name "Name" -MemberType NoteProperty -value $oVMHost.Name
            $OutputObject | Add-Member -Name "State" -MemberType NoteProperty -value $oVMHost.ConnectionState
            $OutputObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $VCServer
            $OutputObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -vmhost $oVMHost) 
            $OutputObject | Add-Member -Name "Vendor" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Vendor
            $OutputObject | Add-Member -Name "Model" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Model
            
            if($oVMHost.ConnectionState -ne "NotResponding"){
                $OutputObject | Add-Member -Name "SerialNumber" -MemberType NoteProperty -value ($oVMHost|get-esxcli -V2).hardware.platform.get.invoke().enclosureserialnumber
                $OutputObject | Add-Member -Name "IPMIIP" -MemberType NoteProperty -value ($oVMHost|get-esxcli -V2).hardware.ipmi.bmc.get.invoke().ipv4address
            }

            $OutputObject | Add-Member -Name "LicenseKey" -MemberType NoteProperty -value $oVMHost.LicenseKey
            $OutputObject | Add-Member -Name "NumCpu" -MemberType NoteProperty -value $oVMHost.NumCpu
            $OutputObject | Add-Member -Name "CryptoState" -MemberType NoteProperty -value $oVMHost.CryptoState
            $OutputObject | Add-Member -Name "Version" -MemberType NoteProperty -value $oVMHost.Version
            $OutputObject | Add-Member -Name "Build" -MemberType NoteProperty -value $oVMHost.Build
            $OutputObject | Add-Member -Name "MemoryTotalGB" -MemberType NoteProperty -value ([math]::Round($oVMHost.MemoryTotalGB,0))
            $OutputObject | Add-Member -Name "MaxEVCMode" -MemberType NoteProperty -value $oVMHost.MaxEVCMode
            $OutputObject | Add-Member -Name "ProcessorType" -MemberType NoteProperty -value $oVMHost.ProcessorType

            $LocationCodeC = ((Get-Cluster -vmhost $ovmhost.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster'}).key)}).value
            $LocationCodeH = ((Get-VMHost -name $ovmhost.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost'}).key)}).value

            if ($LocationCodeC){
                $LocationCode = $LocationCodeC
            }
            else {
                $LocationCode = $LocationCodeH
            }

            $OutputObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode

            if($Datastores){
                $OutputObject | Add-Member -Name "DatastoreName" -MemberType NoteProperty -value $Datastores.Name
                $OutputObject | Add-Member -Name "DatastoreType" -MemberType NoteProperty -value $Datastores.Type
                $OutputObject | Add-Member -Name "DatastoreCapacityGB" -MemberType NoteProperty -value $Datastores.CapacityGB
            }

            if (($oVMHost.extensiondata.hardware.systeminfo.Model).substring(0,6) -eq 'vxrail'){
                foreach ($Datastore in $Datastores){
                    if ($Datastore.name.substring(0,2) -eq 'DE') {
                        $OutputObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $Datastore.Name.substring(0,14)
                    }
                }
            }
            else {
                $OutputObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $null
            }

            $OutputObject | Add-Member -Name "Network" -MemberType NoteProperty -value (Get-VirtualPortGroup -vmhost $oVMHost).name
            $OutputObject | Add-Member -Name "NetworkSwitch" -MemberType NoteProperty -value (Get-Virtualswitch -vmhost $oVMHost).name

            return $OutputObject
        }
        else {
            Write-Error "VMHost not found."
            return $null
        }
    }

    End{}
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
        [psobject] $VMName,
        [Parameter(Mandatory = $true)]
        [psobject] $TargetVM,
        [Parameter(Mandatory = $true)]
        [object] $TargetVC,
        [Parameter(Mandatory = $true)]
        [object] $VMMetaData
    )

    Begin{}

    Process{
        $Private:AllCustomAttributeName = $VMMetaData.AttributeName
        $Private:AllCustomAttributeValue = $VMMetaData.AttributeValue
        $Private:AllCustomAttributeTag = $VMMetaData.AttributeTag
        $Private:CustomAttributeName 
        $Private:CustomAttributeTag
        $Private:AttributeCount = 0

        if ($AllCustomAttributeName){
            foreach ($CustomAttributeName in $AllCustomAttributeName){
                $TargetVM | Set-Annotation -CustomAttribute $CustomAttributeName -Value $AllCustomAttributeValue[$AttributeCount]
                $AttributeCount++
            }

        if ($AllCustomAttributeTag){}
            foreach ($CustomAttributeTag in $AllCustomAttributeTag){
                New-TagAssignment -Tag $CustomAttributeTag -Entity $TargetVM -Server $TargetVC
            }
        }
    }

    End{}
}