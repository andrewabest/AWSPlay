<# 

First jump into AWS IAM console and create a new user and download the credentials, then feed them into here to create a profile.
This profile will then be used when authenticating calls to AWS from the powershell SDK.
The profile is stored against the user account on this computer.

See http://docs.aws.amazon.com/powershell/latest/userguide/specifying-your-aws-credentials.html

#> 

Set-AWSCredentials -AccessKey AKIAIOSFODNN7EXAMPLE -SecretKey wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY -StoreAs MyProfileName
Get-AWSCredentials -ListStoredCredentials