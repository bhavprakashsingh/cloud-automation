#Author: Bhav
#Email: bhas@softwareag.com
#Creation Date: 17th Feb 2023

#kubectl get pv |grep -i released| awk '{print $1}' > released-pv  (always run this first and verify list in  released-pv file and execute rest of commands )
  
for PV in `cat released-pv`; do
  kubectl get pv  $PV 
  kubectl patch pv $PV -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}';
  kubectl get pv  $PV
done
