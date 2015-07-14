function WaitForState ($instanceid, $desiredstate)
{
    while ($true)
    {
        $a = Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceid}
        $state = $a.Instances[0].State.Name
        if ($state -eq $desiredstate)
        {
            break;
        }

        "$(Get-Date) Current State = $state, Waiting for Desired State = $desiredstate"
        Sleep -Seconds 5
    }
}

# First let's create a fresh key pair for the DSC machines

$keyName = "dsc_key_pair";
try
{
    If ((Get-EC2KeyPair -KeyName $keyName))
    {
        Write-Host "Key pair exists, removing and recreating..."
        Remove-EC2KeyPair -KeyName $keyName -Force
    }
}
catch [InvalidOperationException]
{
    Write-Host "Key pair does not yet exist, creating..."
}
finally
{
    (New-EC2KeyPair -KeyName $keyName).KeyMaterial | Out-File $env:USERPROFILE\dsc-key-pair.pem
}

# Along with a new security group

$securityGroupParameters = @{
    VpcId = "vpc-f4ae7591";
    GroupName = "dscSecurityGroup";
    GroupDescription = "For DSC / WinRM operations"
}

$securityGroupId = New-EC2SecurityGroup @securityGroupParameters;

# To push out a DSC configuration to our instance, we need to open the ports for windows remote management on it's security group
# Lets grant our security group inbound permissions for WinRM, along with RD(er)P

$cidrBlocks = New-Object 'collections.generic.list[string]'
$cidrBlocks.add("0.0.0.0/0")

Grant-EC2SecurityGroupIngress -GroupId $securityGroupId -IpPermissions @{IpProtocol = "tcp"; FromPort = 3389; ToPort = 3389; IpRanges = $cidrBlocks}
Grant-EC2SecurityGroupIngress -GroupId $securityGroupId -IpPermissions @{IpProtocol = "tcp"; FromPort = 5985; ToPort = 5985; IpRanges = $cidrBlocks}
Grant-EC2SecurityGroupIngress -GroupId $securityGroupId -IpPermissions @{IpProtocol = "tcp"; FromPort = 5986; ToPort = 5986; IpRanges = $cidrBlocks}

<# 
    This is where the magic happens!
    EC2 instances, when booted, run a process called EC2Config.
    This process scans the user data for either <script> or <powershell> tags
    And will run what is inside them! *MAGIC*
#>

$userdata = @"
<powershell>
Set-ExecutionPolicy Unrestricted -Force
Enable-NetFirewallRule FPS-ICMP4-ERQ-In
Set-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC -RemoteAddress Any
New-NetFirewallRule -Name "WinRM80" -DisplayName "WinRM80" -Protocol TCP -LocalPort 80
New-NetFirewallRule -Name "WinRM443" -DisplayName "WinRM443" -Protocol TCP -LocalPort 443
Enable-PSRemoting -Force
Restart-Service winners
</powershell>
"@

# Userdata has to be base64 encoded
$userdataBase64Encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdata))

$instanceParams = @{
    ImageId = "ami-f9760dc3";
    MinCount = 1;
    MaxCount = 1;
    KeyName = $keyName;
    SecurityGroupId = $securityGroupId;
    InstanceType = "t2.micro" ;
    SubnetId = "subnet-1e1fa07b";
    UserData = $userdataBase64Encoded
}

$newInstance = New-EC2Instance @instanceParams

# Once we have our new instance, we want to extract the DNS name and the administrator password.
# Note that the DNS name is not returned from the New cmdlet, and can only be retrieved once the instance is running
# Once we have these in our hot little hands, we can DSC away!

$instanceId = $newInstance.Instances[0].InstanceId

WaitForState $instanceid "Running"

$publicDNSName = (Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceId}).Instances[0].PublicDnsName
$password = $null
while ($password -eq $null)
{
    try
    {
        $password = Get-EC2PasswordData -InstanceId $instanceId -PemFile $env:USERPROFILE\dsc-key-pair.pem -Decrypt
    }
    catch
    {
        "$(Get-Date) Waiting for PasswordData to be available"
        Sleep -Seconds 10
    }
}

# DSC TIME!!!

# First lets define our configuration 

Configuration WebServerConfiguration
{
  param ([string[]]$computerName = 'localhost')
  Node $computerName
  {
    WindowsFeature Web-AppInit { Ensure = 'Present'; Name = 'Web-AppInit' }
    WindowsFeature Web-Asp-Net45 { Ensure = 'Present'; Name = 'Web-Asp-Net45' }
    WindowsFeature Web-Http-Tracing { Ensure = 'Present'; Name = 'Web-Http-Tracing' }
    WindowsFeature Web-Mgmt-Service { Ensure = 'Present'; Name = 'Web-Mgmt-Service' }
    WindowsFeature Web-Net-Ext { Ensure = 'Present'; Name = 'Web-Net-Ext' }
    WindowsFeature Web-Server { Ensure = 'Present'; Name = 'Web-Server' }
  }
}

# Then we will generate the MOF for it

WebServerConfiguration -ComputerName $publicDNSName -OutputPath $env:USERPROFILE\DSC

# Add the new remote server instance to our trusted hosts so that we can communicate with it via HTTP (Would go via HTTPS in PROD and avoid this step entirely, what a pain!)

winrm s winrm/config/client "@{TrustedHosts=""$publicDNSName""}"

# Then we can push it up to our instance using the password extracted earlier

$securepassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("administrator", $securepassword)
# NOTE: If you have trouble establishing the CIM session, see troubleshooting below
$cimSession = New-CimSession -ComputerName $publicDNSName -Credential $credential -Authentication Negotiate

# GO GO DSC

Start-DscConfiguration -Verbose -Wait -Path $env:USERPROFILE\DSC -Force -CimSession $cimSession

# Troubleshooting CIM sessions / WinRM
# FIRST: Ensure all players in the game (Both Remote AND Local computers) have the Windows Remote Management service turned ON.
# WinRM configuration help https://technet.microsoft.com/en-us/magazine/ff700227.aspx
# WinRM troubleshooting http://blogs.technet.com/b/jonjor/archive/2009/01/09/winrm-windows-remote-management-troubleshooting.aspx

# Cleanup
<#
Get-EC2Instance -Filter @{Name = "instance-id"; Values = $instanceId} | Stop-EC2Instance -Force -Terminate
WaitForState $instanceid "Terminated"
Remove-EC2KeyPair -KeyName $keyName -Force

while ($true)
{
    try
    {
        Write-Host "Attempting to remove security Group"
        Remove-EC2SecurityGroup -GroupId $securityGroupId -Force
    }
    catch
    {
        Sleep -Seconds 5
    }
}
#>
