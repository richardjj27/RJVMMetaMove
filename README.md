# export-vmmetadata
Powershell script to export vCenter metadata to an Excel file.

Right now, the script will export the following data for all VMs on multiple vCenter Servers.
* Attributes (multiple)
* Tags (multiple)
* Attached Disks (multiple)
* Network Adapters (multiple)
* Host information
*   Version
*   Build
* Memory Allocation
* Disk Allocation
* CPU Allocation
* VM Tools Version
* Power State
* Guest OS
* Snapshot Status
* Hosting Cluster
* Notes

Todo:
* Create a 'Set-VMMetadata' function
* Create a 'Migrate' function
*   1. Export (Get-VMMetadata) tags/attributes
*   2. Move
*   3. Import (Set-VMMetadata) tags/attributes
*   4. Check and give update
* Encryption/disk policy
* Maybe split tag/attributes and the rest into separate functions.
