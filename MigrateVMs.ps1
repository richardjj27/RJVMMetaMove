# Script to migrate a list of VMs from one cluster to another.
# Will work across vCenter servers and preserve tags and custom attributes.
# Success/failure written to a log file for later review.

Import-Module -Name vmware.powercli
Remove-Module RJVMMetaMove
Import-Module .\RJVMMetaMove.psm1

$WorkingFolder = "\\gbcp-isilon100.emea.wdpr.disney.com\eiss\Richard\RJVMMetaMove"

$LogFolder = $WorkingFolder + "\Logs"
$LogFile = $LogFolder + "\VM Migration Log $(Get-Date -Format "yyyy-MM-dd_HH.mm").txt"
$VCenterList = $WorkingFolder + "\VCList.csv"
$VMListFile = $WorkingFolder + "\VMListFullGBEQ24-1.csv"
$MovingVMs = $Null

If (!(Test-Path -Path $WorkingFolder)) {
    Write-Host "$WorkingFolder Does not exist. Terminating."
    exit
}

If (!(Test-Path -Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory | Out-Null
}

# Only ask for credentials if they aren't already in memory.
If (!($AdminCredentials)) {
    $AdminCredentials = Get-Credential
}

$VCenters = Import-CSV -Path $VCenterList

ForEach($VCenter in $Vcenters){
    if($VCenter.Server.SubString(0,1) -ne "#") {
        Write-RJLog -LogFile $LogFile -Severity 0 -LogText ("Connecting to " + $VCenter.Server)
        Connect-VIServer -Server $VCenter.Server -Credential $AdminCredentials | Out-Null
        # $VMHosts += get-VMHost -Server $VC
        # $VMGuests += Get-VM -Server $VC
    }
}

Write-RJLog -LogFile $LogFile -Severity 0 -LogText "Reading $VMListFile."
$MovingVMs = Import-CSV -Path $VMListFile
Write-RJLog -LogFile $LogFile

ForEach($MovingVM in $MovingVMs) {
    $InputError = 0
    $RunError = 0
    $SourceVM = Get-VM -Name $MovingVM.SourceVM -ErrorAction SilentlyContinue
    
    $VMMetaData = Get-RJVMMetaData -VMName $SourceVM
    
    $SourceVMHost = $VMMetaData.HostName
    $SourceVC = $VMMetaData.vCenter
    $SourceCluster = $VMMetaData.Cluster
    $SourceResPool = $VMMetaData.ResourcePool
    $SourceDatacenter = $VMMetaData.Datacenter
    $SourceFolder = $VMMetaData.Folder
    $SourceNetwork = $VMMetaData.NetworkAdapter

    $TargetVMHost = $MovingVM.TargetVMHost
    $TargetNetwork = $MovingVM.TargetNetwork
    $TargetDatastore = $MovingVM.TargetDatastore
    $TargetVC = (Get-VMHost -Name $TargetVMHost).uid.Split(":")[0].Split("@")[1]
    $TargetCluster = Get-Cluster -VMHost $TargetVMHost
    $TargetDatacenter = Get-Datacenter -cluster $TargetCluster

    Write-RJLog -LogFile $Logfile -Severity 0 -LogText ("Start migration of " + $SourceVM + " to " + $MovingVM.TargetVMHost + ".")

    # Validate Migration Parameters
    # Is this machine unique and exists?
    If ((Get-VM -Name $MovingVM.SourceVM -ErrorAction SilentlyContinue).count -ne 1) {
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText ($MovingVM.SourceVM + " count isn't 1.")
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
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText "VM appears to be already on the destination cluster."
        $InputError++
    }

    # If all is well, display everything we know and start migration tasks.
    if ($InputError -eq 0){
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source vCenter...... $SourceVC"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source DataCenter... $SourceDatacenter"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Cluster...... $SourceCluster"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Host......... $SourceVMHost"

        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Network...... $SourceNetwork"
          
        
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source ResPool...... $SourceResPool"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Source Folder....... $SourceFolder"

        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target vCenter...... $TargetVC"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target DataCenter... $TargetDatacenter"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Cluster...... $TargetCluster"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Host......... $TargetVMHost"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Network...... $TargetNetwork"
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Target Datastore.... $TargetDatastore"
        
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Collecting Metadata for $SourceVM."
        
        # Get target network specifics.
        $TargetPortGroup = Get-VirtualPortGroup -VMHost $TargetVMHost -Name $TargetNetwork
        Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Start VM migration for $SourceVM to $TargetVMHost."

        # Do 3 pings to the log file just for information.
        $PingSuccess = 0
        If (Resolve-DnsName -name $SourceVM -ErrorAction SilentlyContinue) {
            1..3 | ForEach-Object {
                $PingResult = (Test-connection -target $SourceVM -ping -count 1 -ErrorAction SilentlyContinue).status
                Write-RJLog -LogFile $LogFile -Severity 0 -LogText "Ping result for $SourceVM - $PingResult."
                If ($PingResult -eq "Success") {$PingSuccess++}
                Start-Sleep 1
            }
            Write-RJLog -LogFile $LogFile -Severity 0 -LogText "Ping result for $SourceVM - $PingSuccess/3."
        }
        else { Write-RJLog -LogFile $LogFile -Severity 1 -LogText "DNS resolution for $SourceVM failed." }
    
        # Move the VM
        Write-RJLog -LogFile $LogFile -Severity 0 -LogText "Relocating VMDKs for $SourceVM."
        Move-VM -VM $SourceVM -VMotionPriority High -Destination (Get-VMhost -Name $TargetVMHost) -Datastore (Get-Datastore -Name $TargetDatastore) -DiskStorageFormat Thin -PortGroup $TargetPortGroup | Out-Null

        #### Write the metadata
        $TargetVM = Get-VM -Name $SourceVM
        $TargetVC = $TargetVM.Uid.Split(":")[0].Split("@")[1]
        $VMTargetMetaData = Get-RJVMMetaData -VMName $SourceVM

        # Check the VM host is different after the migration - basically, did it migrate?
        if ($VMMetaData.HostName -eq $VMTargetMetaData.HostName) {
            Write-RJLog -LogFile $Logfile -Severity 3 -LogText "Relocation of $SourceVM failed for some unknown reason.  Review vCenter logs and coonsole for more information."
            $RunError++
        }
        else {
            Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Relocation of $SourceVM VMDKs succeeded."
            # Move to Resource Pool
            # 1. Is the VM actually in a non root level ResourcePool?  i.e. is it in a Resource Pool called 'Resources' which is the root level default.
            If (!($SourceResPool -eq "Resources")) {
                # 2. Does this Resource Pool exist on the target cluster?
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Does the Resource Pool $SourceResPool exist?"
                $DestResPool = Get-ResourcePool $SourceResPool -Location $TargetCluster -ErrorAction 'SilentlyContinue'
                If (!($DestResPool.Name)) {
                    # 3. Create the non-existent Resource Pool on the TargetCluster.
                    New-ResourcePool -Name $SourceResPool -Location $TargetCluster -ErrorAction 'SilentlyContinue' | out-null
                    $DestResPool = Get-ResourcePool $SourceResPool -Location $TargetCluster -ErrorAction 'SilentlyContinue'
                }
                # 3. Move the VM into the Resource Pool.
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Move $SourceVM to Resource Pool."
                Move-VM -VM $SourceVM.Name -Location $DestResPool -ErrorAction SilentlyContinue | out-null
            }

            # Move to Folder
            # 1. Is the VM actually in a non root level Folder?  i.e. is it in a Folder called 'vm' which is the root level default.
            If (!($SourceFolder.name -eq "vm")) {
                # 2. Does this Folder exist on the target cluster?
                $DestFolder = Get-Folder $SourceFolder.name -Location $TargetDatacenter.name -Server $TargetVC -ErrorAction 'SilentlyContinue'
                If (!($DestFolder.Name)) {
                    # 3. Create the non-existent Folder on the TargetCluster.
                    Write-RJLog -LogFile $Logfile -Severity 1 -LogText "Folder Doesn't Exist.  Create $SourceFolder."
                    new-Folder -Name $SourceFolder.name -Location (Get-Folder vm -Location $TargetDatacenter.name -server $TargetVC) -Server $TargetVC -ErrorAction 'SilentlyContinue' | out-null
                    $DestFolder = Get-Folder $SourceFolder.name -Location $TargetDatacenter.name -Server $TargetVC -ErrorAction 'SilentlyContinue'
                 }
                # 3. Move the VM into the Folder.
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Move $SourceVM to Folder."
                Move-VM -VM $SourceVM.Name -InventoryLocation $DestFolder -ErrorAction SilentlyContinue | out-null
            }

            Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Writing Metadata for $SourceVM."
            Set-RJVMCustomAttributes -TargetVM $TargetVM -VMMetaData $VMMetaData -TargetVC $TargetVC 
            
            # Get Metadata for the migrated VM so that it can be compared to the source.
            $VMTargetMetaData = Get-RJVMMetaData -VMName $SourceVM
            
            # Are the attribute names the same as before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeName | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeName | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute names for $SourceVM succeeded."} 
                else {
                Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of attribute names for $SourceVM failed."
                $RunError = $RunError + 0.01
            }

            # Are the attribute values the same before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeValue | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeValue | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of attribute values for $SourceVM succeeded."}
                else {
                Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of attribute values for $SourceVM failed."
                $RunError = $RunError + 0.01
            }

            # Are the tags the same as before?
            if ((Compare-Object -ReferenceObject @($VMMetaData.AttributeTag | Select-Object) -DifferenceObject @($VMTargetMetaData.AttributeTag | Select-Object)).count -eq 0) {
                Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of tags for $SourceVM succeeded."}
                else {
                Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of tags for $SourceVM failed."
                $RunError = $RunError + 0.01
            }

            # Do 5 pings to the log file just for information.
            If (Resolve-DnsName -name $SourceVM -ErrorAction SilentlyContinue) {
                1..5 | ForEach-Object {
                    $PingResult = (Test-connection -target $SourceVM -ping -count 1 -ErrorAction SilentlyContinue).status
                    If ($PingResult -eq "Success") {$PingSuccess--}
                    Write-RJLog -LogFile $LogFile -Severity 0 -LogText "Ping result for $SourceVM - $PingResult."
                    Start-Sleep 1
                }
                If ($PingSuccess -gt 0) {
                    Write-RJLog -LogFile $LogFile -Severity 3 -LogText "Post migration pings for $SourceVM look sub-optimal.  Needs investigation."
                }
            }
            else { Write-RJLog -LogFile $LogFile -Severity 0 -LogText "DNS resolution for $SourceVM failed." }
            
        }

        # If no run errors were recorded, report success!
        if ($RunError -eq 0) {
            Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration of $SourceVM succeeded without errors."
        }
        
        if ($RunError -gt 0 -and $RunError -lt 1) {
            Write-RJLog -LogFile $Logfile -Severity 2 -LogText "Migration of $SourceVM succeeded with errors.  Review vCenter logs and console for more information. ($RunError)"
        }

    }
    else {
        Write-RJLog -LogFile $Logfile -Severity 3 -LogText "Migration of $SourceVM failed validation - skipping."
    }
    Write-RJLog -LogFile $LogFile
    Write-RJLog -LogFile $LogFile
}

Write-RJLog -LogFile $LogFile
Write-RJLog -LogFile $LogFile -Severity 0 "Migration Summary:"
Write-RJLog -LogFile $LogFile -Severity 0 -LogText ("VM Name".PadRight(25) + " | " + "Cluster".PadRight(25) + " | Host")

ForEach($MovingVM in $MovingVMs) {
    $Result = Get-RJVMMetaData -VMName $MovingVM.SourceVM
    Write-RJLog -LogFile $LogFile -Severity 0 -LogText (($Result.Name).PadRight(25) + " | " + ($Result.Cluster.Name).PadRight(25) + " | " + $Result.HostName)
}

Write-RJLog -LogFile $LogFile
Write-RJLog -LogFile $Logfile -Severity 0 -LogText "Migration batch completed."

#Disconnect-VIServer -Server * -Confirm:$false