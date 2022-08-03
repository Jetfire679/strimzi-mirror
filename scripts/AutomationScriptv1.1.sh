#!/bin/bash


# Steps
vStep1="Disassociate: MSK Route53 Record from Primary East-1 Cluster"
vStep2="Associate MSK Vanity Domain Name to West-2 Cluster, Disassociate Schema Registry Route 53 record from East-1"
vStep3="Deploy West-2 Schema Registry: leader eligibility = true and  "
vStep4="Exit"

# Repos
vRepoMSK="git@github.com:Jetfire679/tf-msk.git"
vRepoServices="git@github.com:Jetfire679/msk-services.git"


# FQDNs
vMskVanityFqdn="dev1.test.vignali.rocks"

# Misc variables
vDate=$(date +"%m-%d-%Y:%H-%M")



echo $vMskVanityFqdn

echo Cloning Repo
echo ============
git clone "$vRepoMSK" &> /dev/null
echo

# DomainCheckCommand="nslookup $DomainName 8.8.8.8 | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs | sed 's/8.8.8.8//g'"
# echo $DomainCheckCommand
# eval InitDnsCheck=$DomainCheckCommand
# echo $InitDnsCheck
# echo $InitDnsResults


# if [ -z "$InitDnsCheck" ]
# then
#       InitDnsCheck=false
# else
#       InitDnsCheck=true
# fi



# if grep -q 'enable_msk_dns = true' ./tf-msk/terraform.tfvars; then
#     InitRepoCheck=true
# elif grep -q 'enable_msk_dns = false' ./tf-msk/terraform.tfvars; then
#     InitRepoCheck=false
# else
#     InitRepoCheck=error
# fi


# echo $InitDnsCheck
# echo $InitRepoCheck

# read -r -p "Press any key to continue..." key

if grep -q 'enable_msk_dns = true' ./tf-msk/terraform.tfvars; then

    echo
    echo
    echo --- VCS has Primary DNS Record enabled and set to true in US-East-1 ---
    echo ==========================================================================
    grep enable_msk_dns ./tf-msk/terraform.tfvars


    sleep 2
    echo
    echo
    echo --- Do you wish to Disassociate the DNS Record from the US-East-1?
    echo ==============================
    
    PS3='Selection:'
    lst=("Yes" "No")
    select sel in "${lst[@]}"; do
        case $sel in
            "Yes")
                echo "DisAssociating Record from the product US-East-1 Cluster"
                cd ./tf-msk
                git checkout -b "fail_over-$vDate"
                sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' ./terraform.tfvars
                git commit -a -m "Disassociating Record to the product US-East-1 Cluster"
                git push -u origin "fail_over-$vDate"
                sleep 3
                cd ..
                rm -rf ./tf-msk
                echo
                echo ====================================================================================
                echo ====================================================================================
                echo --- Please proceed to github and create a new pull request from branch: fail_over ---
                echo ====================================================================================
                echo ====================================================================================
            break
                ;;
        "No")
            echo
            echo "Exiting"
            echo =========
            rm -rf ./tf-msk
            exit
            ;;
            *) echo "invalid option $REPLY";;
        esac
    done
elif grep -q 'enable_msk_dns = false' ./tf-msk/terraform.tfvars; then
    echo
    echo =====================================================================================
    echo =====================================================================================
    echo According to VCS, the MSK vanity URL should be resolving to US-East-1
    echo =====================================================================================
    echo =====================================================================================
    sleep 5

    PS3='Producton Kafka DNS is not associated.  Associate it? '
    lst=("Yes" "No")
    select sel in "${lst[@]}"; do
        case $sel in
            "Yes")
                echo "Associating Record from the product US-East-1 Cluster"
                cd ./tf-msk
                git checkout -b fail_over
                sed -i 's/enable_msk_dns = false/enable_msk_dns = true/g' ./terraform.tfvars
                git commit -a -m "Disassociating Record to the product US-East-1 Cluster"
                git push -u origin fail_over
                sleep 3
                cd ..
                rm -rf ./tf-msk
                echo
                echo ============================================================================
                echo ============================================================================
                echo Please proceed to github and create a new pull request from brach: fail_over
                echo ============================================================================
                echo ============================================================================
            break
                ;;
        "No")
            echo
            echo "Exiting"
            echo =========
            rm -rf ./tf-msk
            exit
            ;;
            *) echo "invalid option $REPLY";;
        esac
    done
else
    echo Not Found
fi


