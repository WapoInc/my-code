



New-SelfSignedCertificate `
  -certstorelocation cert:\localmachine\my `
  -dnsname www.contoso.com

#---------------------------------------------------------------------------------------
# copy the Thumbprint from the Output and Paste into Line 22

     PSParentPath: Microsoft.PowerShell.Security\Certificate::LocalMachine\my

Thumbprint                                Subject                                     
----------                                -------                                     
D630DB84E981ED486E27D15DE86BEE2B0C332118  CN=www.contoso.com         


#---------------------------------------------------------------------------------------
  $pwd = ConvertTo-SecureString -String <your password> -Force -AsPlainText
Export-PfxCertificate `
  -cert cert:\localMachine\my\E1E81C23B3AD33F9B4D1717B20AB65DBB91AC630 `
  -FilePath c:\appgwcert.pfx `
  -Password $pwd



