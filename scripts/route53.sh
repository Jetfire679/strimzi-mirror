#!/bin/sh

# NOTE:
# Make sure that the value of Name, Type, TTL are the same with your DNS Record Set

HOSTED_ZONE_ID=Z05471843RNAQFU8FZXA


DNS_NAME=msk.test.vignali.rocks
RESOURCE_VALUE=dev1.us-east-1.test.vignali.rocks

# DNS_NAME=schema.test.vignali.rocks
# RESOURCE_VALUE=schema.us-east-1.test.vignali.rocks

# RECORD_TYPE=A
RECORD_TYPE=CNAME
TTL=300
ACTION=CREATE
#ACTION=UPSERT
# ACTION=DELETE
# ACTION=CREATE


JSON_FILE=file.json

(
cat <<EOF
{
    "Comment": "Delete single record set",
    "Changes": [
        {
            "Action": "$ACTION",
            "ResourceRecordSet": {
                "Name": "$DNS_NAME.",
                "Type": "$RECORD_TYPE",
                "TTL": $TTL,
                "ResourceRecords": [
                    {
                        "Value": "${RESOURCE_VALUE}"
                    }
                ]                
            }
        }
    ]
}
EOF
) > $JSON_FILE

aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://$JSON_FILE

# rm $JSON_FILE

# echo "Deleting record set ..."
echo
echo "Operation Completed."