# Automated AWS CLI script
# Autor: Rickard Andersson      
# NOTE: At row 33 and 36 the key-name is set to key1, have a key with that name or change it
#

echo "The installation/configuration just started, please wait.."
# Create VPC
vpc_id=$(aws ec2 create-vpc --cidr-block 172.168.0.0/16 --query Vpc.VpcId --output text)

# create-subnets, attached to the vpc, 172.169.39.0 Finance, 172.168.41.0 IT
subnet1_id=$(aws ec2 create-subnet --cidr-block 172.168.39.0/24 --vpc-id "$vpc_id" --query Subnet.SubnetId --output text)
subnet2_id=$(aws ec2 create-subnet --cidr-block 172.168.41.0/24 --vpc-id "$vpc_id" --query Subnet.SubnetId --output text)

# create internet-gateway
igw=$(aws ec2 create-internet-gateway --output text)
    int_gateway_id=$(echo "$igw" | awk '{print $2}')

# attach gateway to vpc
aws ec2 attach-internet-gateway --internet-gateway-id "$int_gateway_id" --vpc-id "$vpc_id"
sleep 5

# map a public ip when an instance is launched so it's accessable 
aws ec2 modify-subnet-attribute --subnet-id "$subnet1_id" --map-public-ip-on-launch

# create security group
secgroup1_id=$(aws ec2 create-security-group --group-name SecGroup --description "Security-group-Finance" --vpc-id "$vpc_id" --query 'GroupId' --output text)
secgroup2_id=$(aws ec2 create-security-group --group-name SecGroup2 --description "Security-group-IT" --vpc-id "$vpc_id" --query 'GroupId' --output text)

# adding a ingress to the security group 2
aws ec2 authorize-security-group-ingress --group-id "$secgroup2_id" --protocol tcp --port 80 --cidr 0.0.0.0/0

# create instance, Finance
instance1_id=$(aws ec2 run-instances --image-id ami-042e8287309f5df03 --count 1 --instance-type t2.micro --key-name key1 --security-group-ids "$secgroup1_id" --subnet-id "$subnet1_id" --query "Instances[].InstanceId" --output text)

# create instance 2, IT
instance2_id=$(aws ec2 run-instances --image-id ami-042e8287309f5df03 --count 1 --instance-type t2.micro --key-name key1 --security-group-ids "$secgroup2_id" --subnet-id "$subnet2_id" --query "Instances[].InstanceId" --output text)

# allocate an elastic Ip, IT
allocate=$(aws ec2 allocate-address --domain vpc --network-border-group us-east-1 --output text)
allocation_id=$(echo "$allocate" | awk '{print $1}')
elastic_ip=$(echo "$allocate" | awk '{print $4}')

# let the cli sleep for a while so the instance can catch up
sleep 30

# associate the elastic IP, IT
allocation_id=$(aws ec2 associate-address --instance-id "$instance2_id" --public-ip "$elastic_ip" --query 'AllocationId' --output text)

# create route table
table_id=$(aws ec2 create-route-table --vpc-id "$vpc_id" --query RouteTable.RouteTableId --output text)

sleep 5
# create route to the internet
create_route=$(aws ec2 create-route --route-table-id "$table_id" --destination-cidr-block 0.0.0.0/0 --gateway-id "$int_gateway_id")

sleep 5

# Associate route-table with subnet1
association1_id=$(aws ec2 associate-route-table --route-table-id "$table_id" --subnet-id "$subnet1_id")
sleep 5

# Associate route-table with subnet2
association2_id=$(aws ec2 associate-route-table --route-table-id "$table_id" --subnet-id "$subnet2_id")

echo "VPC created, ID: $vpc_id"
echo "Subnet1 created, ID: $subnet1_id"
echo "Subnet2 created, ID: $subnet2_id"
echo "The subnets are attached to: $vpc_id"
echo "Internet-gateway created, ID: $int_gateway_id"
echo "Security-group created: $secgroup1_id, in the vpc: $vpc_id"
echo "Security-group2 created: $secgroup2_id, in the vpc: $vpc_id"
echo "Two instances created, ID's: $instance1_id, $instance2_id"
echo "Elastic ip address: $elastic_ip"
echo "Route table created, ID: $table_id"
echo ""
echo "Installation completed.."

exit 0 
