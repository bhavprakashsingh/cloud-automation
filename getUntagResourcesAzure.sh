#!/bin/bash
# Script to get a list of all untagged resources in Azure
# Author: Bhav
# Email: bhas@softwareag.com
# Creation Date: 28th DEC 2023

# Get a list of all the resource group names
rgs=$(az group list --query "[].name" -o tsv)

# Initialize the count variables for untagged resources
untagged_disks_count=0
untagged_snapshots_count=0
untagged_ips_count=0
untagged_nics_count=0

# Iterate through each resource group to get the untagged resources
for rg in $rgs; do
  untagged_disks_count_rg=0
  untagged_snapshots_count_rg=0
  untagged_ips_count_rg=0
  untagged_nics_count_rg=0

  echo "Untagged Disk Details in resource group $rg:"
  disks=$(az disk list -g $rg --query "[?tags == null].id" -o tsv)
  untagged_disks_count_rg=$(az disk list -g $rg --query "[?tags == null].id" -o tsv | wc -l)
  for disk in $disks; do
    echo "Disk: $disk"
  done
  echo ""

  echo "Untagged Snapshot Details in resource group $rg:"
  snapshots=$(az snapshot list -g $rg --query "[?tags == null].id" -o tsv)
  untagged_snapshots_count_rg=$(az snapshot list -g $rg --query "[?tags == null].id" -o tsv | wc -l)
  for snapshot in $snapshots; do
    echo "Snapshot: $snapshot"
  done
  echo ""

  echo "Untagged Public IP Details in resource group $rg:"
  ips=$(az network public-ip list -g $rg --query "[?tags == null].id" -o tsv)
  untagged_ips_count_rg=$(az network public-ip list -g $rg --query "[?tags == null].id" -o tsv | wc -l)
  for ip in $ips; do
    echo "Public IP: $ip"
  done
  echo ""

  #echo "Untagged Network Interface Details in resource group $rg:"
  #nics=$(az network nic list -g $rg --query "[?tags == null].id" -o tsv)
  #untagged_nics_count_rg=$(az network nic list -g $rg --query "[?tags == null].id" -o tsv | wc -l)
  #for nic in $nics; do
  # echo "Network Interface: $nic"
  #done
  echo ""

  # Add the counts for this resource group to the total counts
  untagged_disks_count=$((untagged_disks_count + untagged_disks_count_rg))
  untagged_snapshots_count=$((untagged_snapshots_count + untagged_snapshots_count_rg))
  untagged_ips_count=$((untagged_ips_count + untagged_ips_count_rg))
  #untagged_nics_count=$((untagged_nics_count + untagged_nics_count_rg))

  echo "Total untagged resources in resource group $rg:"
  echo "  Disks: $untagged_disks_count_rg"
  echo "  Snapshots: $untagged_snapshots_count_rg"
  echo "  Public IPs: $untagged_ips_count_rg"
  #echo "  Network Interfaces: $untagged_nics_count_rg"
  echo ""
  echo ""
done

echo "Total untagged resources in all resource groups:"
echo "  Total Disks: $untagged_disks_count"
echo "  Total Snapshots: $untagged_snapshots_count"
echo "  Total Public IPs: $untagged_ips_count"
#echo "  Total Network Interfaces: $untagged_nics_count"
