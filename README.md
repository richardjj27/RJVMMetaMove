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

# Todo:
#   Add:
#       disks - done
#       datastores (single or multiple) - done
#       networks - done
#   Make the authentication to a vcenter an object - done
#   Make the loop through each VM not $xxx - done
#   Create a 'Set-VMMetadata' function
#   Maybe split tag/attributes and the rest into separate functions. - no
#   Make output file a variable. - done
#   Progress bar
#   Move to Git.
#   Use a more secure credentials object.
