# EventLogToElasticSearch v1
# This script uploads Windows Event Logs to an ElasticSearch cluster
# Set this up in Task Scheduler to run with frequency based on the set interval (in minutes)

####################################################   Define variables
# Double-check this section to ensure all variables have proper values before running this script
$log_path = "$PSScriptRoot\Log\log.txt"
$current_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

#- Define credential to use in web request
#- Avoid putting plaintext password at all cost! This is just to simplify it here.
#- For an ecnryption solution, please see my code snippets in https://github.com/lambdac0de/encrypt_credential
$ES_username = '<username>'
$ES_password = '<password>'
$password_secret = ConvertTo-SecureString -AsPlainText -Force -String $ES_password
$credential = New-Object -TypeName System.Management.Automation.PSCredential($ES_username, $ES_password)

#- ElasticSearch Hosts
#- Enumerate all ElasticSearch hosts in the cluster that exposes the API layer
$ES_host = @(
"<ES_host_1>",
"<ES_host_2>",
"<ES_host_3>",
"<ES_host_4>",
"<ES_host_5>") | Get-Random

$ES_Uri = "http://$ES_host`:9200" # <-- This will be used the API endpoint to access ElasticSearch
$ES_index = '<index>'
$ES_type = '<type>'
$RESTUri = $ES_Uri + '/' + $ES_index +'/' + $ES_type + '/' + '_bulk' # <-- This will be the API endpoint to do bulk upload in ElasticSearch

#- Timing/ Frequency
#- Adjust these values as needed, depending on performance
$event_interval = 5 # interval of events in event logs to query
$bulk_interval = 1000 # number of events to push to ES by bulk upload at a time

#- Event Log Sources
#- Enumerate all Windows hosts whose event logs you want to forward to ElasticSearch
$targetServers = @("<eventlog_server_1>",
                   "<eventlog_server_2>",
                   "<eventlog_server_3>",
                   "<eventlog_server_4>",
                   "<eventlog_server_5>")

$filterTable = @{'LogName'='<Event_log_Name>'; # <-- Event Log Name could be as simple as System, Application, or Security, or it could be the more complex ones in the 'Applications and Services Logs'
                 'StartTime'=(Get-Date).AddMinutes(-$event_interval);
                 'EndTime'=(Get-Date)}

# Constant attributes, no need to edit these
$bulk_count = 1
$bulk_message = [string]::Empty
####################################################

# Define upload process
function Bulk-Upload {
    param(
    [string] $Uri,
    [string] $Message)

    try {
        $result = Invoke-WebRequest -Uri $Uri -Method Post -Body $message -Credential $credential -UseBasicParsing -ErrorAction Stop
        if ($result.StatusCode -ne 200 -and $result.StatusDescription -ne "OK") {
            $result.Content >> c:\temp\content.txt
            $current_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output ("$current_date REST Method POST failed on " + $_.MachineName + " with Record ID " + $_.RecordId) >> $log_path
            Write-Output ("$current_date" + $result.StatusDescription + ": " + $result.RawContent) >> $log_path
        }
    }
    catch {
        $current_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "$current_date $_" >> $log_path
    }
}

# Create Filtered Event Log Object
$targetServers | foreach {
    $server = $_
    try {
        Get-WinEvent -FilterHashTable $filterTable -ComputerName $server -ErrorAction Stop | foreach {
            $eventJson = ([ordered]@{'EventId'=$_.Id;
                                     'RecordId'=$_.RecordId;
                                     'ProviderName'=$_.ProviderName;
                                     'LogName'=$_.LogName;
                                     'Source'=$_.MachineName;
                                     'UserId'=$_.UserId;
                                     'TimeCreated'=$_.TimeCreated.ToString("o");
                                     'Level'=$_.LevelDisplayName;
                                     'Task'=$_.TaskDisplayName;
                                     'Keywords'=$_.KeywordsDisplayNames;
                                     'Message'=$_.Message;
                                    } | ConvertTo-Json -Compress).Replace('\r\n','\n').Replace('\t','    ').Replace('\u','>')
        
            if (![string]::IsNullOrWhiteSpace($eventJson) -and $eventJson -ne $null) {
                $bulk_message += "{ `"index`" : {} }`n"
                $bulk_message += ($eventJson + "`n")
            }
        
            if ($bulk_count -ge $bulk_interval) {
                Bulk-Upload -Uri $RESTUri -Message $bulk_message
                $bulk_count = 0
                $bulk_message = [string]::Empty
            }
            $bulk_count++
        }

        if (![string]::IsNullOrWhiteSpace($bulk_message)) {
            Bulk-Upload -Uri $RESTUri -Message $bulk_message
            $bulk_message = [string]::Empty
        }
    }
    catch {
        $current_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output ("$current_date Failed to process event log; $_") >> $log_path
    }
}