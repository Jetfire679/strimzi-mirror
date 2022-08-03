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



#DNS
vMskVanityDNS=msk.test.vignali.rocks
vMskPrimaryDNS=dev1.us-east-1.test.vignali.rocks
vMskSecondaryDNS=dev1.us-east-2.test.vignali.rocks

vSchemaRegVanityDNS=schema.test.vignali.rocks
vSchemaRegPrimaryDNS=schema.us-east-1.test.vignali.rocks
vSchemaRegSecondaryDNS=schema.us-west-2.test.vignali.rocks

vHostedZoneID=Z05471843RNAQFU8FZXA
vDnsResourceValue=toolbox.us-east-1.test.vignali.rocks

vDnsAction=UPSERT
# RECORD_TYPE=CNAME
# TTL=300
# ACTION=UPSERT
# ACTION=DELETE
# ACTION=CREATE

vTempDnsFile=TempDns.json

# Misc variables
vDate=$(date +"%m-%d-%Y--%H-%M")

# Clone the Repo
# echo -e "\033[1;32m------------\033[m"
# echo -e "\033[1;32mCloning Repo\033[m"
# echo -e "\033[1;32m------------\033[m"
git clone "$vRepoMSK" &> /dev/null
git clone "$vRepoServices" &> /dev/null
echo

PS3='Choose Action to Take: '
vSelectionArray=("$vStep1" "$vStep2" "$vStep3" "$vStep4")
select vSelection in "${vSelectionArray[@]}"; do
    case $vSelection in
        "$vStep1")
            # Check vcs config and exit if configuration is not what it is expected - enabling of MSK DNS
            if grep -q 'schema_registry_subdomain = "secondary"' $vMskPrimaryTfVarsPath; then
                vTempSetting=""
                vTempSetting=$(grep 'enable_msk_dns' $vMskPrimaryTfVarsPath)
                echo ""
                echo -e "\033[1;32mCheck configurations, schema registry subdomain may be resolving to secondary region\033[m"
                echo "$vMskPrimaryTfVarsPath config: $vTempSetting"
                echo ""
                read -r -p "Press any enter to continue..." key                                               
            # Proceed with making necessary config changes to support the fail over activity from the primary region to secondary
            elif grep -q 'enable_msk_dns = true' $vMskPrimaryTfVarsPath; then

                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"     
                echo -e "\033[1;32mDisassociating the following DNS Records:\033[m"
                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"                     
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vMskVanityDNS.']"
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vSchemaRegVanityDNS.']"


                # Disassociated the MSK Vanity DNS Record
                echo "{">> $vTempDnsFile
                echo " \"Comment\": \"Delete single record set\",">> $vTempDnsFile
                echo " \"Changes\": [">> $vTempDnsFile
                echo "   {" >> $vTempDnsFile
                echo "     \"Action\": \"DELETE\"," >> $vTempDnsFile
                echo "     \"ResourceRecordSet\": {"  >> $vTempDnsFile
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vMskVanityDNS.']" | tail -n +3 | head -n -1 >> $vTempDnsFile
                echo "  }"  >> $vTempDnsFile
                echo " ]"  >> $vTempDnsFile
                echo "}"  >> $vTempDnsFile
                
                aws route53 change-resource-record-sets --hosted-zone-id ${vHostedZoneID} --change-batch file://$vTempDnsFile

                rm $vTempDnsFile
                
                # Disassociated the Schema Registry DNS record
                echo "{">> $vTempDnsFile
                echo " \"Comment\": \"Delete single record set\",">> $vTempDnsFile
                echo " \"Changes\": [">> $vTempDnsFile
                echo "   {" >> $vTempDnsFile
                echo "     \"Action\": \"DELETE\"," >> $vTempDnsFile
                echo "     \"ResourceRecordSet\": {"  >> $vTempDnsFile
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vSchemaRegVanityDNS.']" | tail -n +3 | head -n -1 >> $vTempDnsFile
                echo "  }"  >> $vTempDnsFile
                echo " ]"  >> $vTempDnsFile
                echo "}"  >> $vTempDnsFile
                               
                aws route53 change-resource-record-sets --hosted-zone-id ${vHostedZoneID} --change-batch file://$vTempDnsFile

                rm $vTempDnsFile

                echo -e "\033[1;32m-----------------------------------------------------------------------------------"
                echo "Ensure that no new messages are being produced before continuing to the next step."
                echo "-----------------------------------------------------------------------------------"


                rm -rf ./kafka
                rm -rf ./services         
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
            elif grep -q 'schema_registry_leader_elgibility = false' $vMskSecondaryTfVarsPath; then
                #Set Current State for reference
                vCurrentSchemaLeaderElig=$(grep 'schema_registry_leader_elgibility' $vMskSecondaryTfVarsPath)
                vCurrentSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)
                
                # change directory to create the branch
                cd ./kafka
                echo ""
                
                # Checkout a new branch so that it can be merged with main/master and initiate the codebuild and terraform pipline
                git checkout -b "fail-over-stg2-$vDate" --quiet 2> /dev/null
                cd ..

                # Update the tfvars file to allow terraform to update the domain names after merging with main/master
                sed -i 's/schema_registry_leader_elgibility = false/schema_registry_leader_elgibility = true/g' $vMskSecondaryTfVarsPath
                sed -i 's/schema_registry_subdomain = "primary-fo"/schema_registry_subdomain = "primary"/g' $vMskSecondaryTfVarsPath

                # Set Updated variables to the new config for reference and comparison at the end of this stage.
                vUpdatedSchemaLeaderElig=$(grep schema_registry_leader_elgibility $vMskSecondaryTfVarsPath)
                vUpdatedSchemaSubdomain=$(grep schema_registry_subdomain $vMskSecondaryTfVarsPath)


                # change directory and commit changes to vcs
                cd ./kafka
                git commit -a -m "Disassociating MSK and Schema Registry records from the primary region's configuration" --quiet 2> /dev/null
                git push -u origin "fail-over-stg2-$vDate" --quiet 2> /dev/null

                # Present before and after details for review.
                echo ""
                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"                
                echo -e "\033[1;32mThe following changes will be ready for merging from the following branch:\033[m"
                echo -e "\033[1;36m"fail-over-stg2-$vDate"\033[m"
                echo ""
                echo -e "\033[1;32mThe Schema Registery DNS record will be updated as part of the deply.\033[m"                
                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"                
                echo "$vMskPrimaryTfVarsPath config changes:"               
                echo -e " - FROM: \033[1;33m$vCurrentSchemaLeaderElig\033[m" 
                echo -e "  --> TO: \033[1;31m$vUpdatedSchemaLeaderElig\033[m"
                echo -e " - FROM: \033[1;33m$vCurrentSchemaSubdomain\033[m"
                echo -e "  --> TO: \033[1;31m$vUpdatedSchemaSubdomain\033[m"
                read -r -p "Press any enter to continue..." key                  

                cd ..

                echo "{">> $vTempDnsFile
                echo "    \"Comment\": \"Creating the following Cname\",">> $vTempDnsFile
                echo "    \"Changes\": [">> $vTempDnsFile
                echo "        {">> $vTempDnsFile
                echo "            \"Action\": \"$vDnsAction\",">> $vTempDnsFile
                echo "            \"ResourceRecordSet\": {">> $vTempDnsFile
                echo "                \"Name\": \"$vMskVanityDNS.\",">> $vTempDnsFile
                echo "                \"Type\": \"CNAME\",">> $vTempDnsFile
                echo "                \"TTL\": 300,">> $vTempDnsFile
                echo "                \"ResourceRecords\": [">> $vTempDnsFile
                echo "                    {">> $vTempDnsFile
                echo "                        \"Value\": \"${vMskSecondaryDNS}\"">> $vTempDnsFile
                echo "                    }">> $vTempDnsFile
                echo "                ]">> $vTempDnsFile               
                echo "            }">> $vTempDnsFile
                echo "        }">> $vTempDnsFile
                echo "    ]">> $vTempDnsFile
                echo "}">> $vTempDnsFile

                aws route53 change-resource-record-sets --hosted-zone-id ${vHostedZoneID} --change-batch file://$vTempDnsFile
                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"  
                echo -e "\033[1;32mAssociated the following DNS Record:\033[m"
                echo -e "\033[1;32m------------------------------------------------------------------------------\033[m"                  
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vMskVanityDNS.']"
                
                rm $vTempDnsFile

                rm -rf ./kafka
                rm -rf ./services              
            else
                echo Unexpected result, exiting.
            fi
	    break
            ;;
        "$vStep3")
            echo "$vSelection"

                echo "{">> $vTempDnsFile
                echo "    \"Comment\": \"Creating the following Cname\",">> $vTempDnsFile
                echo "    \"Changes\": [">> $vTempDnsFile
                echo "        {">> $vTempDnsFile
                echo "            \"Action\": \"$vDnsAction\",">> $vTempDnsFile
                echo "            \"ResourceRecordSet\": {">> $vTempDnsFile
                echo "                \"Name\": \"$vMskVanityDNS.\",">> $vTempDnsFile
                echo "                \"Type\": \"CNAME\",">> $vTempDnsFile
                echo "                \"TTL\": 300,">> $vTempDnsFile
                echo "                \"ResourceRecords\": [">> $vTempDnsFile
                echo "                    {">> $vTempDnsFile
                echo "                        \"Value\": \"${vMskPrimaryDNS}\"">> $vTempDnsFile
                echo "                    }">> $vTempDnsFile
                echo "                ]">> $vTempDnsFile               
                echo "            }">> $vTempDnsFile
                echo "        }">> $vTempDnsFile
                echo "    ]">> $vTempDnsFile
                echo "}">> $vTempDnsFile

                aws route53 change-resource-record-sets --hosted-zone-id ${vHostedZoneID} --change-batch file://$vTempDnsFile

                rm $vTempDnsFile



                echo "{">> $vTempDnsFile
                echo "    \"Comment\": \"Creating the following Cname\",">> $vTempDnsFile
                echo "    \"Changes\": [">> $vTempDnsFile
                echo "        {">> $vTempDnsFile
                echo "            \"Action\": \"$vDnsAction\",">> $vTempDnsFile
                echo "            \"ResourceRecordSet\": {">> $vTempDnsFile
                echo "                \"Name\": \"$vSchemaRegVanityDNS.\",">> $vTempDnsFile
                echo "                \"Type\": \"CNAME\",">> $vTempDnsFile
                echo "                \"TTL\": 300,">> $vTempDnsFile
                echo "                \"ResourceRecords\": [">> $vTempDnsFile
                echo "                    {">> $vTempDnsFile
                echo "                        \"Value\": \"${vSchemaRegPrimaryDNS}\"">> $vTempDnsFile
                echo "                    }">> $vTempDnsFile
                echo "                ]">> $vTempDnsFile               
                echo "            }">> $vTempDnsFile
                echo "        }">> $vTempDnsFile
                echo "    ]">> $vTempDnsFile
                echo "}">> $vTempDnsFile


                aws route53 change-resource-record-sets --hosted-zone-id ${vHostedZoneID} --change-batch file://$vTempDnsFile

                rm $vTempDnsFile

                echo -e "\033[1;32mAssociated the following DNS Record:\033[m"
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vMskVanityDNS.']"
                aws route53 list-resource-record-sets --hosted-zone-id $vHostedZoneID --output json --query "ResourceRecordSets[?Name == '$vSchemaRegVanityDNS.']"



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

