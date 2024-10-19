#!/bin/bash

# Get a list of all the resource group names
rgs=$(az group list --query "[].name" -o tsv)

# Temporary file for collecting output
output_file=$(mktemp)

# Header for the output
echo -e "Customer Name\tVnet Name\tCIDR\tGroup" > "$output_file"

# Iterate through each resource group to get the VNets
for rg in $rgs; do
  # Trim any whitespace or newline characters from the resource group name
  rg=$(echo "$rg" | tr -d '[:space:]')

  # Get all VNets in the resource group
  vnets=$(az network vnet list -g "$rg" --query "[].{Name:name, ID:id, CIDR:addressSpace.addressPrefixes, Tags:tags}" -o json) 2>> rg.txt
  
  # Check if the az command was successful
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to retrieve VNets for resource group $rg" >&2
    echo "az network vnet list -g \"$rg\" command failed." >> rg.txt
    echo "Error message: $(az network vnet list -g "$rg" --query "[].{Name:name, ID:id, CIDR:addressSpace.addressPrefixes, Tags:tags}" -o json 2>&1)" >> rg.txt
    continue
  fi

  # Check if there are any VNets in the resource group
  if [ "$(echo "$vnets" | jq -r '. | length')" -eq 0 ]; then
    echo "No VNets found in resource group $rg." >> rg.txt
    continue
  fi

  # Iterate through each VNet to get the details
  echo "$vnets" | jq -c '.[]' | while read -r vnet; do
    vnet_name=$(echo "$vnet" | jq -r '.Name')
    cidr=$(echo "$vnet" | jq -r '.CIDR[]')
    customer_name=$(echo "$vnet" | jq -r '.Tags.Customer')
    
    # Append the details to the output file in a tab-separated format
    echo -e "${customer_name:-N/A}\t$vnet_name\t$cidr\t$rg" >> "$output_file"
  done
done

# Print the collected output in a pretty format
column -t -s $'\t' < "$output_file"

# Remove the temporary file
rm "$output_file"
