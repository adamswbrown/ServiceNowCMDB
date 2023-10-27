# Define your ServiceNow instance and credentials
$uri = 'https://xxx.service-now.com/api/now/table/'
$user = "xxx"
$pass = "xxx"

# Convert to SecureString
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force

# Create PSCredential object
$credentials = New-Object System.Management.Automation.PSCredential ($user, $secpasswd)

# Define headers
$headers = @{"Accept" = "application/json"}

# Get CI relationships
$relCI = Invoke-RestMethod -Uri ($uri + 'cmdb_rel_ci?sysparm_fields=sys_id,type,parent,child') -Method Get -Credential $credentials -Headers $headers
Write-Host ("Number of CI relationships: " + $relCI.result.count)

# Get Relationship Types
$relTypes = Invoke-RestMethod -Uri ($uri + 'cmdb_rel_type') -Method Get -Credential $credentials -Headers $headers
Write-Host ("Number of different types of relationships: " + $relTypes.result.count)

# Get CIs
$CIs = Invoke-RestMethod -Uri ($uri + 'cmdb_ci_server') -Method Get -Credential $credentials -Headers $headers
Write-Host ("Number of CIs: " + $CIs.result.count)

# Fetch the list of applications
$appCI = Invoke-RestMethod -Uri ($uri + 'cmdb_ci_appl') -Method Get -Credential $credentials -Headers $headers
Write-Host ("Number of Apps: " + $appCI.result.count)

$finalResult = @()

foreach ($server in $CIs.result) {
    $serverRels = $relCI.result | Where-Object { ($_.parent.value -eq $server.sys_id) -or ($_.child.value -eq $server.sys_id)}
    
    Write-Host -ForegroundColor Green "Processing server: $($server.name) - Found $($serverRels.count) relationships"

    $classification = $server.classification
    $os = $server.os

    foreach ($rel in $serverRels) {
        $appSysId = If ($rel.parent.value -eq $server.sys_id) { $rel.child.value } Else { $rel.parent.value }
        $app = $appCI.result | Where-Object { $_.sys_id -eq $appSysId }

        # Find the relationship type descriptor
        $relType = $relTypes.result | Where-Object { $_.sys_id -eq $rel.type.value }
        $childDescriptor = if ($relType) { $relType.child_descriptor } else { "Unknown" }

        # If no app is found, set app details to "Unknown"
        if ($app -eq $null) {
            $appName = "Unknown"
            Write-Host "No application found for relationship with AppSysId: $appSysId and Type: $childDescriptor"
        } else {
            $appName = $app.name
            Write-Host "Found app: $appName for server: $($server.name)"
        }

        # Update the object with server, application, and relationship details
        $obj = [PSCustomObject]@{
            'ServerName'        = $server.name
            'ServerSysId'       = $server.sys_id
            'AppName'           = $appName
            'AppSysId'          = $appSysId
            'RelationshipType'  = $childDescriptor
            'Classification'    = $classification
            'OS'                = $os
        }
        
        # Add the object to the final result array
        $finalResult += $obj
    }
}

$finalResult | Export-Csv -Path './FinalResult.csv' -NoTypeInformation -Force
