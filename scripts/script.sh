git clone git@github.com:Jetfire679/tf-msk.git
cd ./tf-msk
git checkout -b fail_over
echo ===============
echo Current setting
grep enable_msk_dns ./terraform.tfvars
echo ===============
echo "Do you wish to associate the MSK name with East-1's cluster?"
select yn in "Yes" "No"; do
    case $yn in
        Associate ) echo One; break;;
        Disassociate ) echo Two; break;;
        exit ) exit;;
    esac
done
echo 
grep enable_msk_dns ./terraform.tfvars
echo Updating terraform.tfvars 
# sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' ./terraform.tfvars
sed -i 's/enable_msk_dns = true/enable_msk_dns = false/g' ./terraform.tfvars
echo Modified setting
grep enable_msk_dns ./terraform.tfvars
git add . -A
git commit -m "Updated failover DNS - enable_msk_dns = true"
git push -u origin fail_over
cd ..
# rm -rf ./tf-msk