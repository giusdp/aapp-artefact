#!/bin/bash

cd opentofu
tofu apply -auto-approve

echo "Created VMs."
echo "Sleeping for 30 seconds before running Ansible..."

sleep 30

cd ../ansible
ansible-playbook site.yaml

if [ $? -ne 0 ]; then
    echo "Ansible playbook failed. Exiting."
    exit 1
fi

echo "Deployed OpenWhisk."

echo "Sleeping for 15 minutes to give some time to OpenWhisk..."
sleep 900 # sleep for another 15 minutes to give time to OpenWhisk to deploy completely

cd ..

./prepare_wsk.sh

./create_tagged_actions.sh

./invoke_all_actions.sh

echo "All actions invoked. Check Controller logs to see where the actions were scheduled."
echo "Use ./connect-master.sh to connect to the master node."
echo "Then run 'kubectl logs owdev-controller-0 -n openwhisk' to see the logs."