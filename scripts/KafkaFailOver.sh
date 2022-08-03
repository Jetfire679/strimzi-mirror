#!/bin/bash


# Steps
vStep1="Disassociate: MSK and Schema Registry DNS Record from Primary region"
vStep2="Associate MSK snd Schema Registry DNS and also enable leadership eligibility in Secondary region"
vStep3="TBD"
vStep4="Exit"

# Repos
vRepoMSK="git@github.com:Jetfire679/kafka.git"
vRepoServices="git@github.com:Jetfire679/services.git"
vMskPrimaryTfVarsPath="./kafka/config/deployment/primary/terraform.tfvars"
vMskSecondaryTfVarsPath="./kafka/config/deployment/secondary/terraform.tfvars"
vCaspianRepoName=""


# FQDNs
vMskVanityFqdn="dev1.test.vignali.rocks"

# Misc variables
vDate=$(date +"%m-%d-%Y--%H-%M")

# Clone the Repo
echo -e "\033[1;32m------------\033[m"
echo -e "\033[1;32mCloning Repo\033[m"
echo -e "\033[1;32m------------\033[m"
git clone "$vRepoMSK" &> /dev/null
git clone "$vRepoServices" &> /dev/null
echo

PS3='Choose Action to Take: '
vSelectionArray=("$vStep1" "$vStep2" "$vStep3" "$vStep4")
select vSelection in "${vSelectionArray[@]}"; do
    case $vSelection in
        "$vStep1")
            echo "$vSelection"
            # Check vcs config and exit if configuration is not what it is expected - enabling of MSK DNS
            if grep -q 'enable_msk_dns = false' $vMskPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mNothign to do Exiting - MSK Route 53 record is not associated with East-1 cluster\033[m"
                echo "$vMskPrimaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key
            # Check vcs config and exit if configuration is not what it is expected - schema registry DNS    
            elif grep -q 'schema_registry_subdomain = "secondary"' $vMskPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mCheck configurations, schema registry subdomain may be resolving to secondary region\033[m"
                echo "$vMskPrimaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                                               
            # Proceed with making necessary config changes to support the fail over activity from the primary region to secondary
            elif grep -q 'enable_msk_dns = true' $vMskPrimaryTfVarsPath; then
                #Set Current State for reference
                vCurrentEnableMskDns=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                vCurrentSchemaSubdomain=$(grep schema_registry_subdomain $vMskPrimaryTfVarsPath)
                
                # change directory to create the branch
                cd ./kafka
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-over-stg1-$vDate" --quiet 2> /dev/null
                cd ..
                
                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' $vMskPrimaryTfVarsPath
                sed -i 's/schema_registry_subdomain = "primary"/schema_registry_subdomain = "primary-fo"/g' $vMskPrimaryTfVarsPath
                
                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedEnambleMskDns=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                vUpdatedSchemaSubdomain=$(grep schema_registry_subdomain $vMskPrimaryTfVarsPath)
                echo ""

                # change directory and commit changes to vcs
                cd ./kafka
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration" --quiet 2> /dev/null
                git push -u origin "fail-over-stg1-$vDate" --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vMskPrimaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentEnableMskDns\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedEnambleMskDns\033[m"
                echo -e " - FROM: \033[1;33m$vCurrentSchemaSubdomain\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedSchemaSubdomain\033[m"
                read -r -p "Press any enter to continue..." key                  
                echo -e "\033[1;32m------------------------------------------------------------------------------"
                echo "REMINDER Check Kowl messages to ensure nothing new has been produced before"
                echo "continuing to the next step."
                echo ""
                echo "No changes will be applied until the vcs changes are merged and the codebuild" 
                echo "pipeline and Terraform is run."
                echo "------------------------------------------------------------------------------"
                echo -e "\033[m"
                cd ..
                rm -rf ./kafka 
            else
                echo Unexpected result, exiting.
            fi
	    # optionally call a function or run some code here
        break
            ;;
        "$vStep2")
            echo "$vSelection"
            # update vMskSecondaryTfVarsPath to:
            # enable_msk_dns = true
            # schema_registry_leader_elgibility = true
            if grep -q 'schema_registry_leader_elgibility = true' $vMskSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'schema_registry_leader_elgibility' $vMskSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that leadership eligibility is set to enabled in the secondary region.\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                
            elif grep -q 'schema_registry_subdomain = "primary"' $vMskSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that the Schema Registry DNS record is already associated with the secondary region.\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key               
            elif grep -q 'enable_msk_dns = false' $vMskSecondaryTfVarsPath; then
                #Set Current State for reference
                vCurrentEnambleMskDns=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                vCurrentSchemaLeaderElig=$(grep 'schema_registry_leader_elgibility' $vMskSecondaryTfVarsPath)
                vCurrentSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)
                
                # change directory to create the branch
                cd ./kafka
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-over-stg2-$vDate" --quiet
                cd ..

                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/enable_msk_dns = false/enable_msk_dns = true/g' $vMskSecondaryTfVarsPath
                sed -i 's/schema_registry_leader_elgibility = false/schema_registry_leader_elgibility = true/g' $vMskSecondaryTfVarsPath
                sed -i 's/schema_registry_subdomain = "primary-fo"/schema_registry_subdomain = "primary"/g' $vMskSecondaryTfVarsPath

                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedEnambleMskDns=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                vUpdatedSchemaLeaderElig=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                vUpdatedSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)


                # change directory and commit changes to vcs
                cd ./kafka
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration" --quiet
                git push -u origin "fail-over-stg2-$vDate" --quiet

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vMskPrimaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentEnambleMskDns\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedEnambleMskDns\033[m"                
                echo -e " - FROM: \033[1;33m$vCurrentSchemaLeaderElig\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedSchemaLeaderElig\033[m"
                echo -e " - FROM: \033[1;33m$vCurrentSchemaSubdomain\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedSchemaSubdomain\033[m"
                read -r -p "Press any enter to continue..." key                  
                echo -e "\033[1;32m------------------------------------------------------------------------------"
                echo "REMINDER Check Kowl messages to ensure nothing new has been produced before"
                echo "continuing to the next step."
                echo ""
                echo "No changes will be applied until the vcs changes are merged and the codebuild" 
                echo "pipeline and Terraform is run."
                echo "------------------------------------------------------------------------------"
                echo -e "\033[m"
                cd ..
                rm -rf ./kafka
                rm -rf ./services              
            else
                echo Unexpected result, exiting.
            fi
	    break
            ;;
        "$vStep3")
            echo "$vSelection"
            rm -rf ./kafka
            rm -rf ./services
	    # optionally call a function or run some code here
	    break
            ;;
	"$vStep4")
	    echo "Exiting per your request.  No changes made."
        rm -rf ./kafka
        rm -rf ./services
	    exit
	    ;;
        *) echo "invalid option $REPLY";;
    esac
done

