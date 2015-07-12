<# 

First jump into AWS IAM console and create a new user and download the credentials, then feed them into here to create a profile.
This profile will then be used when authenticating calls to AWS from the powershell SDK.
The profile is stored against the user account on this computer.

See http://docs.aws.amazon.com/powershell/latest/userguide/specifying-your-aws-credentials.html

#>

Set-AWSCredentials -AccessKey AKIAIOSFODNN7EXAMPLE -SecretKey wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY -StoreAs RahzarCredentialProfile
Get-AWSCredentials -ListStoredCredentials

# Get-AWSRegion # Get the list of AWS regions
Set-DefaultAWSRegion -Region ap-southeast-2
Get-DefaultAWSRegion

Initialize-AWSDefaults -ProfileName RahzarCredentialProfile -Region ap-southeast-2

<#

Credentials Search Order

When you run a command, PowerShell Tools searches for credentials in the following order and uses the first available set.

Use literal credentials that are embedded in the command line.

We strongly recommend using profiles rather than putting literal credentials in your command lines.

Use a specified profile name or profile location.

If you specify only a profile name, use a specified profile from the SDK Store and, if that does not exist, the specified profile from the credentials file in the default location.

If you specify only a profile location, use the default profile from that credentials file.

If you specify a name and a location, use the specified profile from that credentials file.

If the specified profile or location is not found, the command throws an exception. Search proceeds to the following steps only if you have not specified a profile or location.

Use credentials specified by the -Credentials parameter.

Use a session profile.

Use a default profile, in the following order:

The default profile in the SDK store.

The default profile in the credentials file.

Use the AWS PS Default profile in the SDK Store.

If you are using running the command on an Amazon EC2 instance that is configured for an IAM role, use EC2 instance credentials stored in an instance profile.

For more information about using IAM roles for Amazon EC2 Instances, go to the AWS Developer Guide for .NET.

If this search fails to locate the specified credentials, the command throws an exception.

#> 