
$endpoints = @(
  "management.azure.com",
  "login.microsoftonline.com",
  "login.windows.net",
  "westeurope.his.arc.azure.com",
  "guestconfiguration.azure.com"
)

foreach ($e in $endpoints) {
  Test-NetConnection $e -Port 443
}
