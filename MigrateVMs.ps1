Import-Module -Name vmware.powercli
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$LogFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\richard\vCenterExport\Logs\VM Migration Log $(get-date -Format "yyyy-MM-dd_HH.mm").txt"
#$VMListFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\richard\vCenterExport\VMListFullGBEQ24.txt"
$VMListFile = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\richard\vCenterExport\VMListFullGBEQ42.txt"

$Credentials = Get-Credential
Connect-VIServer -Server "su-gbcp-vvcsa02.emea.wdpr.disney.com" -Credential $Credentials | Out-Null
Connect-VIServer -Server "su-gbcp-vvcsa03.emea.wdpr.disney.com" -Credential $Credentials | Out-Null
Connect-VIServer -Server "su-gbcp-vvcsa04.emea.wdpr.disney.com" -Credential $Credentials | Out-Null

# # ILTA Move
# $TargetVMHost = "su-ilta-vxrail01.emea.wdpr.disney.com"
# $TargetNetwork = "PROD_ILTA_VLAN5"
# $TargetDatastore = "VxRail-Virtual-SAN-Datastore-ILTA"

# # TRZE Move
# $TargetVMHost = "su-trze-vxrail01.emea.wdpr.disney.com"
# $TargetNetwork = "Production_45"
# $TargetDatastore = "VxRail-Virtual-SAN-Datastore-a86fa29d-0e1d-4b08-9bf1-633d0064c41d"

$MovingVMs = Import-CSV -Path $VMListFile

ForEach($MovingVM in $MovingVMs) {
    # Todo: Check the VM, target host, network and datastore exist and write log if not.
    $InputError = 0
    $RunError = 0
    $SourceVM = Get-VM -Name $MovingVM.SourceVM -ErrorAction SilentlyContinue
    $SourceVMHost = $SourceVM.vmhost
    $SourceVC = $SourceVM.Uid.Split(":")[0].Split("@")[1]
    $SourceCluster = (Get-Cluster -VM $SourceVM)

    $TargetVMHost = $MovingVM.TargetVMHost
    $TargetNetwork = $MovingVM.TargetNetwork
    $TargetDatastore = $MovingVM.TargetDatastore
    $TargetVC = (Get-VMHost -Name $TargetVMHost).uid.Split(":")[0].Split("@")[1]
    $TargetCluster = (Get-Cluster -VMHost $TargetVMHost)

    Write-RJLog -LogFile $Logfile -Severity 0 -LogText ("Start migration of " + $SourceVM + " to " + $MovingVM.TargetVMHost + ".")

    # Validate Migration Parameters
    # Does the source VM exist?
    If (!(Get-VM -Name $MovingVM.SourceVM -ErrorAction SilentlyContinue)){
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText ($MovingVM.SourceVM + " not found.")
        $InputError++
    }

    # Does the target VM host exist?
    If (!(Get-VMHost $TargetVMHost -ErrorAction SilentlyContinue)){
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText ($TargetVMHost + " not found.")
        $InputError++
    }

    # Does the target Network exist?
    If (!(Get-VirtualPortGroup -VMHost $TargetVMHost -Name $TargetNetwork -ErrorAction SilentlyContinue)){
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText ($TargetNetwork + " not found.")
        $InputError++
    }

    # Does the target Datastore exist?
    If (!(Get-VMHost $TargetVMHost | Get-Datastore $TargetDatastore -ErrorAction SilentlyContinue)){
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText ($TargetDatastore + " not found.")
        $InputError++
    }

    # Are the source and destination datatores different?
    If ($SourceCluster -eq $TargetCluster){
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText "Source and destination are on the same cluster which makes no sense."
        $InputError++
    }

    # If all is well, display everything we know and start migration tasks.
    if ($InputError -eq 0){
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source vCenter...... $SourceVC"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Host......... $SourceVMHost"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Cluster...... $SourceCluster"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target vCenter...... $TargetVC"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Host......... $TargetVMHost"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Cluster...... $TargetCluster"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Network...... $TargetNetwork"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Datastore.... $TargetDatastore"
        
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Collecting metadata for $SourceVM."
        $VMMetaData = Get-RJVMMetaData -VMName $SourceVM

        # Get target network specifics.
        $TargetPortGroup = Get-VirtualPortGroup -VMHost $TargetVMHost -Name $TargetNetwork
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Start VM migration for $SourceVM to $TargetVMHost."
        # Do 3 pings to the log file just for information.
        1..3 | ForEach-Object {
            Write-RJLog -LogFile $LogFile -Severity 0 -LogText (((test-connection -target $VMMetaData.VMHostName -ping -count 1 | Format-Table destination,displayaddress,latency -hidetableheaders | out-string)).trim())
            Start-Sleep 1
        }

        # Move the VM
        Move-VM -VM $SourceVM -VMotionPriority High -Destination (Get-VMhost -Name $TargetVMHost) -Datastore (Get-Datastore -Name $TargetDatastore) -DiskStorageFormat Thin -PortGroup $TargetPortGroup | Out-Null

        #### Write the metadata
        $TargetVM = Get-VM -Name $SourceVM
        $TargetVC = $TargetVM.Uid.Split(":")[0].Split("@")[1]
        $VMTargetMetaData = get-RJVMMetaData -VMName $SourceVM

        # Check the VM host is different after the migration - basically, did it migrate?
        if ($VMMetaData.Host -eq $VMTargetMetaData.Host) {
            Write-RJLog -LogFile $Logfile -Severity 3 -LogText "Migrating of $SourceVM failed for some unknown reason.  Review vCenter logs and coonsole for more information."
            $RunError++
        }
        else {
            Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of $SourceVM VMDKs succeeded."
            Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Writing metadata for $SourceVM."
            Set-RJVMCustomAttributes -TargetVM $TargetVM -VMMetaData $VMMetaData -TargetVC $TargetVC 
            
            # Get Metadata for the migrated VM so that it can be compared to the source.
            $VMTargetMetaData = get-RJVMMetaData -VMName $SourceVM
            
            # Are the attribute names the same as before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeName | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeName | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute names for $SourceVM succeeded."} 
                else {
                Write-RJLog -LogFile $Logfile -Severity 1 -LogText "Migration of attribute names for $SourceVM failed."
                $RunError = $RunError + 0.1
            }

            # Are the attribute values the same s before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeValue | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeValue | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute values for $SourceVM succeeded."}
                else {
                Write-RJLog -LogFile $Logfile -Severity 1 -LogText "Migration of attribute values for $SourceVM failed."
                $RunError = $RunError + 0.1
            }

            # Are the tags the same as before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeTag | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeTag | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of tags for $SourceVM succeeded."}
                else {
                Write-RJLog -LogFile $Logfile -Severity 1 -LogText "Migration of tags for $SourceVM failed."
                $RunError = $RunError + 0.1
            }

            # Do 5 pings to the log file just for information.
            1..5 | ForEach-Object {
                Write-RJLog -LogFile $LogFile -Severity 0 -LogText (((test-connection -target $VMTargetMetaData.VMHostName -ping -count 1 | Format-Table destination,displayaddress,latency -hidetableheaders | out-string)).trim())
                Start-Sleep 1
            }
        }

        # If no run errors were recorded, report success!
        if ($RunError -eq 0) {
            {Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of $SourceVM succeeded without errors."}
        }
        else {
            {Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of $SourceVM succeeded with errors.  Review vCenter logs and coonsole for more information."}
        }

    }
    else {
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText "Migration of $SourceVM failed due to incorrect parameters - skipping."
    }
    Write-RJLog -LogFile $LogFile 
}

Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration batch completed."

Disconnect-VIServer -Server * -Confirm:$false