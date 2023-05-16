# RJVMMetaMove

This project contains four functions plus three wrapper scripts for typical VMWare ESXi vCenter migration and export tasks.

## *RJVMMetaDataMove.psm1*
### *Get-RJVMMetaData*
Get multiple useful attributes and settings for the specified VM.<br>
Returns an object containing numerous attributes of the specfied guest, including custom attributes and tags.

`VMName` The VM guest to be queried.<br>

### *Get-RJVMHostData*
Get multiple useful attributes and settings for the specified VM host.<br>
Returns an object containing numerous attributes of the specified host.

`VMHost` The VM host to be queried.<br>

### *Set-RJVMCustomAttributes*
Set custom attributes for a specific VM derived from previous Get-RJVMMetaData.

`TargetVM` Attribute/Tag object specified below will be written to this VM.<br>
`VNMetadata` Write this metadata object to the above VM.<br>

### *Write-RJLog*
Write a formatted log text to the file specified in $LogFile with timings.

`LogFile` Target for migration log files.<br>
`Severity` The severity of the log entry (0 = information, 1 = debug, 2 = warning, 3 = error)<br>
`LogText` The text to be written.<br>

## The three wrapper scripts.

## *ExportHosts.ps1*
Create a report in Excel for all VM hosts in multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go and the location of teh vCenter list to be processed.<br>
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.<br>
- `$XLOutputFile` - Name and location of the Excel report.<br>
- `$VCenterList` - The script will authenticate these vCenter servers and will be used to populate a list of all hosts.<br>

## *ExportVMs.ps1*
Create a report in Excel for all VM guests in multiple vCenter servers as listed in VCList.csv.

- `$WorkingFolder` - The path of where your export will go and the location of teh vCenter list to be processed.<br>
- `$XLOutputs` - A CSV list of fields to be exported, their order and formatting.<br>
- `$XLOutputFile` - Name and location of the Excel report.<br>
- `$VCenterList` - The script will authenticate these vCenter servers and will be used to populate a list of all guests.<br>

## *MigrateVMs.ps1*
Migrate a list of VMs from one cluster to another (including cross vCenter) preserving tags and custom attributes.

- `$WorkingFolder` - The path of where your output and logs will go, plus your list of servers to be migrated.<br>
- `$LogFile` - The migration log file.<br>
- `$VCenterList` -  The script will authenticate these vCenter servers and is required to for rights to  move guests from the source to the destination hosts. Example included.<br>
- `$VMListFile` - CSV list of VMs to be moved. (SourceVM,TargetVMHost,TargetNetwork,TargetDatastore). Example included.<br>

## *Dependent Files*
### *ExcelOutput.csv*
- Defines the selection, order, formatting and notes for each exported field.<br>
- Target 1 is for the VM hosts report.<br>
- Target 2 is for the VM guests report.<br>

### *VCList.csv*
- Defines the list of vCenter Servers (their FQDN) to be interrogated.  Remark (#) out any which are out of scope.

### *$VMListFile* (specified in code)
- Defines the list of VMs to be migrated.  This needs to provide the following.
1. `SourceVM` - The name of the machine to be moved.<br>
2. `TargetVMHost` - The target VM Host - just pick any host from within the target cluster and let the destination DRS keep things balanced.<br>
3. `TargetNetwork` - The target network.<br>
4. `TargetDatastore` - The target datastore.<br>

It goes without saying that vMotion needs to be routable between the source and destination hosts.  If not, a temporary vMotion kernel can be created using an alternative routable VLAN.  This process is detailed in Jim Shen's excellent article in confluence.
- `https://confluence.disney.com/display/INTLEISS/switchless+2-Node+VxRail+vMotion`

Our hosts do not currently use proper authoritative certificates so the following command may be required to use PowerCli.
- `Set-PowerCliConfiguration -InvalidCertificateAction Ignore`

The installation of the latest version of PowerCLI is required.
