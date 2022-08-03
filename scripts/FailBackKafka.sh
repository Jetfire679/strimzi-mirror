#!/bin/bash


# Steps
vStep1="Disassociate: MSK and Schema Registry DNS Record from Secondary region"
vStep2="Resync to primary region by disabling MM2 in the secondary region, enabling MM2 in the primary region, and Delete all topics in the primary region"
vStep3="After primary sync'd, revert mm2 configuration with mm2 replication from primary to secondary, and topics deleted in secondary region"
vStep4="Associate: MSK and Schema Registry DNS records to the primary region"
vStep5="Exit"

# Repos
vRepoMSK="git@github.com:Jetfire679/kafka.git"
vMskPrimaryTfVarsPath="./kafka/config/deployment/primary/terraform.tfvars"
vMskSecondaryTfVarsPath="./kafka/config/deployment/secondary/terraform.tfvars"
vMskDir="./kafka"

vRepoServices="git@github.com:Jetfire679/services.git"
vServicesPrimaryTfVarsPath="./services/config/deployment/primary/terraform.tfvars"
vServicesSecondaryTfVarsPath="./services/config/deployment/secondary/terraform.tfvars"
VServiceDir="./services"




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
vSelectionArray=("$vStep1" "$vStep2" "$vStep3" "$vStep4" "$vStep5")
select vSelection in "${vSelectionArray[@]}"; do
    case $vSelection in
        "$vStep1")
            echo "$vSelection"
            # Check vcs config and exit if configuration is not what it is expected - enabling of MSK DNS
            if grep -q 'enable_msk_dns = false' $vMskSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mNothign to do Exiting - MSK Route 53 record is not associated with East-1 cluster\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key
            # Check vcs config and exit if configuration is not what it is expected - schema registry DNS    
            elif grep -q 'schema_registry_subdomain = "secondary"' $vMskSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mCheck configurations, schema registry subdomain may be resolving to secondary region\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                                               
            # Proceed with making necessary config changes to support the fail over activity from the primary region to secondary
            elif grep -q 'enable_msk_dns = true' $vMskSecondaryTfVarsPath; then
                #Set Current State for reference
                vCurrentEnambleMskDns=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                vCurrentSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)
                vCurrentSchemaLeaderElig=$(grep 'schema_registry_leader_elgibility' $vMskSecondaryTfVarsPath)
                
                # change directory to create the branch
                cd $vMskDir
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-back-stg1-$vDate" --quiet 2> /dev/null
                cd ..
                
                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' $vMskSecondaryTfVarsPath
                sed -i 's/schema_registry_leader_elgibility = true/schema_registry_leader_elgibility = false/g' $vMskSecondaryTfVarsPath
                sed -i 's/schema_registry_subdomain = "primary"/schema_registry_subdomain = "caspian-kafka-schema-registry-dr1"/g' $vMskSecondaryTfVarsPath
                
                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedEnableMskDns=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                vUpdatedSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)
                vUpdatedSchemaLeaderElig=$(grep 'schema_registry_leader_elgibility' $vMskSecondaryTfVarsPath)
                echo ""

                # change directory and commit changes to vcs
                cd $vMskDir
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration" --quiet 2> /dev/null
                git push -u origin "fail-back-stg1-$vDate" --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vMskSecondaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentEnambleMskDns\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedEnableMskDns\033[m"
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
                rm -rf ./kafka
                rm -rf ./services
            fi
	    # optionally call a function or run some code here
        break
            ;;
        "$vStep2")
            echo "$vSelection"

            if grep -q 'mm2_replicas = 0' $vServicesSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'mm2_replicas' $vServicesSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that mm2 does not have any replicas in the secondary region.\033[m"
                echo "$vServicesSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                
            elif grep -q 'mm2_replicas = 1' $vServicesPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that mm2 does have replicas in the primary region.\033[m"
                echo "$vServicesPrimaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key               
            elif grep -q 'mm2_replicas = 1' $vServicesSecondaryTfVarsPath; then
                #Set Current State for reference
                vCurrentPrimaryMm2Replicas=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                vCurrentSecondaryMm2Replicas=$(grep mm2_replicas $vServicesSecondaryTfVarsPath)
                
                # change directory to create the branch
                cd $VServiceDir
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-back-stg2-$vDate"  --quiet 2> /dev/null
                cd ..

                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/mm2_replicas = 0/mm2_replicas = 1/g' $vServicesPrimaryTfVarsPath
                sed -i 's/mm2_replicas = 1/mm2_replicas = 0/g' $vServicesSecondaryTfVarsPath

                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedPrimaryMm2Replicas=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                vUpdatedSecondaryMm2Replicas=$(grep mm2_replicas $vServicesSecondaryTfVarsPath)


                # change directory and commit changes to vcs
                cd $VServiceDir
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration"  --quiet 2> /dev/null
                git push -u origin "fail-back-stg2-$vDate"  --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vServicesPrimaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentPrimaryMm2Replicas\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedPrimaryMm2Replicas\033[m"
                echo "$vServicesSecondaryTfVarsPath config changes:"                
                echo -e " - FROM: \033[1;33m$vCurrentSecondaryMm2Replicas\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedSecondaryMm2Replicas\033[m"
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
            rm -rf ./kafka
            rm -rf ./services     
	    break
            ;;
        "$vStep3")
            echo "$vSelection"
            if grep -q 'mm2_replicas = 1' $vServicesSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'mm2_replicas' $vServicesSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that mm2 has replicas running in secondary region.\033[m"
                echo "$vServicesSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                
            elif grep -q 'mm2_replicas = 0' $vServicesPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mExiting, version control indicates that mm2 does not have any replicas in the primary region.\033[m"
                echo "$vServicesPrimaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key               
            elif grep -q 'mm2_replicas = 1' $vServicesPrimaryTfVarsPath; then
                #Set Current State for reference
                vCurrentPrimaryMm2Replicas=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                vCurrentSecondaryMm2Replicas=$(grep mm2_replicas $vServicesSecondaryTfVarsPath)
                
                # change directory to create the branch
                cd $VServiceDir
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-back-stg3-$vDate"  --quiet 2> /dev/null
                cd ..

                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/mm2_replicas = 1/mm2_replicas = 0/g' $vServicesPrimaryTfVarsPath
                sed -i 's/mm2_replicas = 0/mm2_replicas = 1/g' $vServicesSecondaryTfVarsPath

                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedPrimaryMm2Replicas=$(grep mm2_replicas $vServicesPrimaryTfVarsPath)
                vUpdatedSecondaryMm2Replicas=$(grep mm2_replicas $vServicesSecondaryTfVarsPath)


                # change directory and commit changes to vcs
                cd $VServiceDir
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration"  --quiet 2> /dev/null
                git push -u origin "fail-back-stg3-$vDate"  --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vServicesPrimaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentPrimaryMm2Replicas\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedPrimaryMm2Replicas\033[m"
                echo "$vServicesSecondaryTfVarsPath config changes:"                
                echo -e " - FROM: \033[1;33m$vCurrentSecondaryMm2Replicas\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedSecondaryMm2Replicas\033[m"
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
            rm -rf ./kafka
            rm -rf ./services     
	    # optionally call a function or run some code here
	    break
            ;;
        "$vStep4")
            echo "$vSelection"
            # Check vcs config and exit if configuration is not what it is expected - enabling of MSK DNS
            if grep -q 'enable_msk_dns = true' $vMskPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mNothign to do Exiting - MSK Route 53 record is not associated with East-1 cluster\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key
            # Check vcs config and exit if configuration is not what it is expected - schema registry DNS    
            elif grep -q 'enable_msk_dns = true' $vMskSecondaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskSecondaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mCheck configs as vcs indicates that the MSK DNS record may still be in use in the secondary region\033[m"
                echo "$vMskSecondaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                                               
            # Proceed with making necessary config changes to support the fail over activity from the primary region to secondary
            elif grep -q 'enable_msk_dns = false' $vMskPrimaryTfVarsPath; then
                #Set Current State for reference
                vCurrentEnambleMskDns=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                vCurrentSchemaSubdomain=$(grep schema_registry_subdomain $vMskPrimaryTfVarsPath)
                
                
                # change directory to create the branch
                cd $vMskDir
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-back-stg4-$vDate" --quiet 2> /dev/null
                cd ..
                
                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/enable_msk_dns = false/enable_msk_dns = true/g' $vMskPrimaryTfVarsPath
                sed -i 's/schema_registry_subdomain = "primary-fo"/schema_registry_subdomain = "caspian-kafka-schema-registry"/g' $vMskPrimaryTfVarsPath
                
                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedEnableMskDns=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                vUpdatedSchemaSubdomain=$(grep schema_registry_subdomain $vMskPrimaryTfVarsPath)
                echo ""

                # change directory and commit changes to vcs
                cd $vMskDir
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration" --quiet 2> /dev/null
                git push -u origin "fail-back-stg4-$vDate" --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32mThe following changes are ready for review and merging.\033[m"
                echo "$vMskPrimaryTfVarsPath config changes:"
                echo -e " - FROM: \033[1;33m$vCurrentEnambleMskDns\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedEnableMskDns\033[m"            
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
                rm -rf ./kafka
                rm -rf ./services
            fi



            echo step 4b
	    # optionally call a function or run some code here
	    break
            ;;            
	"$vStep5")
	    echo "Exiting per your request.  No changes made."
        rm -rf ./kafka
        rm -rf ./services
	    exit
	    ;;
        *) echo "invalid option $REPLY";;
    esac
done

