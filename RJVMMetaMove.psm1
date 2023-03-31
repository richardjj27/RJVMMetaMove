# Todo:
# Create module manifest (.psd1)
# Learn how to keep function parameters private (or not) and whether to pass an object or text is the right thing to do.
# Try to find a way of getting some kind of CPU compatibility information.
# Need to tidy up variable names and follow some kind of convention and scoping.
#   https://stackoverflow.com/questions/27847809/in-powershell-how-to-set-variable-values-within-a-function-and-have-that-value
# Add module version/ing.
# Sort out the Portgroup and Switch export data for host and VM
# Put some logging in place with error checking.
# Writing of tag/attributes writes to console.
# Try to freeze first column in export scripts.

function Get-RJVMMetaData {
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
    
    # Get the virtual machine
    $VM = Get-VM -Name $VMName
    $CustomAttrList = Get-CustomAttribute -Server $VM.Uid.Split(":")[0].Split("@")[1]
    $CustomObject = New-Object -TypeName PSObject

    If ($VM) {
        # Create an object to hold the custom attributes
        $vcserver = $VM.Uid.Split(":")[0].Split("@")[1]

        # --singles
        $CustomObject | Add-Member -Name "VMName" -MemberType NoteProperty -value $VM.name # yes
        $CustomObject | Add-Member -Name "Powerstate" -MemberType NoteProperty -value $vm.powerstate # yes
        $CustomObject | Add-Member -Name "VMVersion" -MemberType NoteProperty -value $VM.extensiondata.config.version # yes
        $CustomObject | Add-Member -Name "MemoryGB" -MemberType NoteProperty -value $vm.memorygb # yes
        $CustomObject | Add-Member -Name "CPUCores" -MemberType NoteProperty -value $vm.NumCpu # yes
        $CustomObject | Add-Member -Name "ToolsVersion" -MemberType NoteProperty -value $vm.extensiondata.guest.toolsversion # yes
        $CustomObject | Add-Member -Name "GuestOS" -MemberType NoteProperty -value $vm.extensiondata.guest.guestfullname # yes
        $CustomObject | Add-Member -Name "VMCreated" -MemberType NoteProperty -value $VM.extensiondata.config.createdate # yes
        $CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value $vcserver # yes
        $CustomObject | Add-Member -Name "Host" -MemberType NoteProperty -value (get-vmhost -vm $vm).name # yes
        $CustomObject | Add-Member -Name "HostVersion" -MemberType NoteProperty -value (get-vmhost -vm $vm).version # yes
        $CustomObject | Add-Member -Name "HostBuild" -MemberType NoteProperty -value (get-vmhost -vm $vm).build # yes
        $CustomObject | Add-Member -Name "Datacenter" -MemberType NoteProperty -value (Get-Datacenter -Server $vcserver -vm $vm.name) # yes
        $CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value (Get-Cluster -Server $vcserver -vm $vm.name) # yes
        $CustomObject | Add-Member -Name "ResourcePool" -MemberType NoteProperty -value (Get-ResourcePool -Server $vcserver -VM $VM) # yes
        $CustomObject | Add-Member -Name "Folder" -MemberType NoteProperty -value $vm.folder # yes
        $CustomObject | Add-Member -Name "Notes" -MemberType NoteProperty -value $vm.notes # check
        $CustomObject | Add-Member -Name "Snapshot" -MemberType NoteProperty -value ($vm | get-snapshot).created # yes
        
        $outputCustomAttrKey = @()
        $outputCustomAttrName = @()
        $outputCustomAttrValue = @()
        $CustomAttributes = $VM.ExtensionData.CustomValue

        foreach ($attribute in $CustomAttributes) {
            if ($attribute.Value) {
                $outputCustomAttrKey += $attribute.key

                $outputCustomAttrName += ($CustomAttrList | where-object {$_.Key -eq $Attribute.Key}).Name
                
                $outputCustomAttrValue += $attribute.value
            }
        }
        
        $LocationCodeC = ((Get-Cluster -vm $vm.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster'}).key)}).value
        $LocationCodeH = ((Get-VMHost -vm $vm.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost'}).key)}).value

        if ($LocationCodeC){
            $LocationCode = $LocationCodeC
        }
        else {
            $LocationCode = $LocationCodeH
        }

        $CustomObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode
        $CustomObject | Add-Member -Name "AttributeName" -MemberType NoteProperty -value $outputCustomAttrName
        $CustomObject | Add-Member -Name "AttributeValue" -MemberType NoteProperty -value $outputCustomAttrValue
        $CustomObject | Add-Member -Name "AttributeTag" -MemberType NoteProperty -value (Get-TagAssignment -Entity $VM).Tag.Name

        $outputDiskDatastore = @()
        $HardDisks = get-HardDisk -VM $VM
        
        foreach ($HardDisk in $HardDisks) {
            $outputDiskDatastore += ($HardDisk.Filename | select-string '(?<=\[)[^]]+(?=\])').matches.value
        }

        $CustomObject | Add-Member -Name "NetworkAdapter" -MemberType NoteProperty -value (Get-NetworkAdapter -VM $VM).NetworkName
        $CustomObject | Add-Member -Name "DiskLayoutStorageFormat" -MemberType NoteProperty -value (get-HardDisk -VM $VM).StorageFormat
        $CustomObject | Add-Member -Name "DiskLayoutPersistence" -MemberType NoteProperty -value (get-HardDisk -VM $VM).Persistence
        $CustomObject | Add-Member -Name "DiskLayoutDiskType" -MemberType NoteProperty -value (get-HardDisk -VM $VM).DiskType
        $CustomObject | Add-Member -Name "DiskDatastore" -MemberType NoteProperty -value $outputDiskDatastore
        $CustomObject | Add-Member -Name "DiskName" -MemberType NoteProperty -value (get-HardDisk -VM $VM).Name
        $CustomObject | Add-Member -Name "DiskSizeGB" -MemberType NoteProperty -value (get-HardDisk -VM $VM).CapacityGB

        return $CustomObject
    }

    else {
        Write-Error "Virtual machine not found."
        return $null
    }
}

function Get-RJVMHostData {
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
        [psobject] $VMHost
    )

    $oVMHost = get-vmhost -name $VMHost
    $CustomAttrList = Get-CustomAttribute -Server $oVMHost.Uid.Split(":")[0].Split("@")[1]

    if($oVMHost){
        $CustomObject = New-Object -TypeName PSObject

        $CustomObject | Add-Member -Name "Name" -MemberType NoteProperty -value $oVMHost.Name
        $CustomObject | Add-Member -Name "State" -MemberType NoteProperty -value $oVMHost.ConnectionState
        $CustomObject | Add-Member -Name "vCenter" -MemberType NoteProperty -value ($oVMHost.Uid.Split(":")[0].Split("@")[1])
        $CustomObject | Add-Member -Name "Cluster" -MemberType NoteProperty -value $oVMHost.parent
        $CustomObject | Add-Member -Name "Vendor" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Vendor
        $CustomObject | Add-Member -Name "Model" -MemberType NoteProperty -value $oVMHost.extensiondata.hardware.systeminfo.Model
        
        if($oVMHost.ConnectionState -ne "NotResponding"){
            $CustomObject | Add-Member -Name "SerialNumber" -MemberType NoteProperty -value ($oVMHost|get-esxcli -V2).hardware.platform.get.invoke().enclosureserialnumber
            $CustomObject | Add-Member -Name "IPMIIP" -MemberType NoteProperty -value ($oVMHost|get-esxcli -V2).hardware.ipmi.bmc.get.invoke().ipv4address
        }

        $CustomObject | Add-Member -Name "LicenseKey" -MemberType NoteProperty -value $oVMHost.LicenseKey
        $CustomObject | Add-Member -Name "NumCpu" -MemberType NoteProperty -value $oVMHost.NumCpu
        $CustomObject | Add-Member -Name "CryptoState" -MemberType NoteProperty -value $oVMHost.CryptoState
        $CustomObject | Add-Member -Name "Version" -MemberType NoteProperty -value $oVMHost.Version
        $CustomObject | Add-Member -Name "Build" -MemberType NoteProperty -value $oVMHost.Build
        $CustomObject | Add-Member -Name "MemoryTotalGB" -MemberType NoteProperty -value ([math]::Round($oVMHost.MemoryTotalGB,0))
        $CustomObject | Add-Member -Name "MaxEVCMode" -MemberType NoteProperty -value $oVMHost.MaxEVCMode
        $CustomObject | Add-Member -Name "ProcessorType" -MemberType NoteProperty -value $oVMHost.ProcessorType

        $LocationCodeC = ((Get-Cluster -vmhost $ovmhost.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'Cluster'}).key)}).value
        $LocationCodeH = ((Get-VMHost -name $ovmhost.name).ExtensionData.customvalue |where-object {$_.key -eq (($CustomAttrList | where-object {$_.Name -eq 'Location ID' -and $_.TargetType -eq 'VMHost'}).key)}).value

        if ($LocationCodeC){
            $LocationCode = $LocationCodeC
        }
        else {
            $LocationCode = $LocationCodeH
        }

        $CustomObject | Add-Member -Name "LocationCode" -MemberType NoteProperty -value $LocationCode

        $Datastores = get-datastore -vmhost $oVMHost
        if($Datastores){
            $CustomObject | Add-Member -Name "DatastoreName" -MemberType NoteProperty -value $Datastores.Name
            $CustomObject | Add-Member -Name "DatastoreType" -MemberType NoteProperty -value $Datastores.Type
            $CustomObject | Add-Member -Name "DatastoreCapacityGB" -MemberType NoteProperty -value $Datastores.CapacityGB
        }

        if (($oVMHost.extensiondata.hardware.systeminfo.Model).substring(0,6) -eq 'vxrail'){
            foreach ($ds in $Datastores){
                if ($ds.name.substring(0,2) -eq 'DE') {
                    $CustomObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $ds.Name.substring(0,14)
                }
            }
        }
        else {
            $CustomObject | Add-Member -Name "PSNT" -MemberType NoteProperty -value $null
        }

        $vdSwitches = get-vdswitch -VMHost $oVMHost
        if($vdSwitches) {
            $CustomObject | Add-Member -Name "vdPortGroupName" -MemberType NoteProperty -value $vdSwitches.Name
        }

        return $CustomObject
    }
    else {
        Write-Error "VMHost not found."
        return $null
    }
}

# what is the difference between and [object] and a [psobject].
# should I be passing objects or just the text?
function Set-RJVMCustomAttributes {
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

    $AllCustomAttributeName = $VMMetaData.AttributeName
    $AllCustomAttributeValue = $VMMetaData.AttributeValue
    $AllCustomAttributeTag = $VMMetaData.AttributeTag

    $attrcount = 0

    if ($AllCustomAttributeName){
        foreach ($CustomAttributeName in $AllCustomAttributeName){
            $TargetVM | Set-Annotation -CustomAttribute $CustomAttributeName -Value $AllCustomAttributeValue[$attrcount]
            $attrcount++
        }

    if ($AllCustomAttributeTag){}
        foreach ($CustomAttributeTag in $AllCustomAttributeTag){
            New-TagAssignment -Tag $CustomAttributeTag -Entity $TargetVM -Server $TargetVC # $VMMetaDataItem.Tag
        }
    }
}