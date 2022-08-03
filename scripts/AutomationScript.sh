#!/bin/bash

git clone git@github.com:Jetfire679/tf-msk.git

echo ===============
echo Current setting
grep enable_msk_dns ./tf-msk/terraform.tfvars
echo ===============

PS3='Produciton Kafka DNS associate in US-East-1: '
lst=("Associate" "Disassociate" "Quit")
select sel in "${lst[@]}"; do
    case $sel in
        "Associate")
            echo "Associating Record to the product US-East-1 Cluster"
            cd ./tf-msk
            git checkout -b fail_over
            sed -i 's/enable_msk_dns = false/enable_msk_dns = true/g' ./terraform.tfvars
            grep enable_msk_dns ./terraform.tfvars
            git commit -a -m "Associating Record to the product US-East-1 Cluster"
            git push -u origin fail_over
            cd ..
            # rm -rf ./tf-msk
        break
            ;;
        "Disassociate")
            echo "Disassociating Record to the product US-East-1 Cluster"
            cd ./tf-msk
            git checkout -b fail_over
            sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' ./terraform.tfvars
            git commit -a -m "Disassociating Record to the product US-East-1 Cluster"
            git push -u origin fail_over
            cd ..
            # rm -rf ./tf-msk
	    break
            ;;
	"Quit")
	    echo "User requested exit"
	    exit
	    ;;
        *) echo "invalid option $REPLY";;
    esac
done