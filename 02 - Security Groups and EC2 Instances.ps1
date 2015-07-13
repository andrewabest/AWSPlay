# First we will create a keypair so that we can rdp into our instance once it is created
(New-EC2KeyPair -KeyName "default_key_pair").KeyMaterial | Out-File .\default-key-pair.pem

# Lets list our vpcs and identify which one we want to work in
Get-EC2Vpc

# Lets list our subnets too, and choose one of those to place our instance in
Get-EC2Subnet

# Now we will create a new security group for our instances to operate within
$securityGroupParameters = @{
    VpcId = "vpc-f4ae7591";
    GroupName = "defaultSecurityGroup";
    GroupDescription = "Where all the cool instances hang out"
}

$securityGroupId = New-EC2SecurityGroup @securityGroupParameters;

# Remove-EC2SecurityGroup -GroupName "defaultSecurityGroup"

# And lets grant our new security group some RDP permissions so that we can get into them once created
$cidrBlocks = New-Object 'collections.generic.list[string]'
$cidrBlocks.add("0.0.0.0/0")
$ipPermissions = New-Object Amazon.EC2.Model.IpPermission 
$ipPermissions.IpProtocol = "tcp" 
$ipPermissions.FromPort = 3389 
$ipPermissions.ToPort = 3389 
$ipPermissions.IpRanges = $cidrBlocks
Grant-EC2SecurityGroupIngress -GroupName "defaultSecurityGroup" -IpPermissions $ipPermissions

# Verify the IP Permissions were created
($securityGroupId | Get-EC2SecurityGroup).IpPermissions  

# Lets find the AIM we want to use as a template for our machine
Get-EC2ImageByName # List images by name
Get-EC2ImageByName -Names WINDOWS_2012R2_BASE # Get specific image details so that we can retrieve the aim_id

# Okay we have our info now, GO GO GO!
$instanceParams = @{
    ImageId = "ami-f9760dc3";
    MinCount = 2;
    MaxCount = 2;
    KeyName = "default_key_pair";
    SecurityGroupId = $securityGroupId;
    InstanceType = "t2.micro" ;
    SubnetId = "subnet-1e1fa07b";
}

New-EC2Instance @instanceParams

Get-EC2Instance

# Once we are all done, let's clean up our instances so save some $$$
(Get-EC2Instance).Instances | Stop-EC2Instance -Terminate