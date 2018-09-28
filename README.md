# eventlogs_to_elasticsearch
This is a script to upload events from Windows Event Logs to ElasticSearch

## What is this for?
Anyone who has worked with Windows event logs knows that it is extremely inefficient. Event Viewer tends to be slow, and event logs are padded with unnecessary information. Storing such events in a resilient datastore like ElasticSearch is a much better option both for log analysis and storage. This script is a simple solution to move logs from native Windows Event Logs to an ElasticSearch cluster. This is intended to be an interim solution, until a more enterprise approach is set up, like a full ELK implementation or using SIEM forwarding agents like Snare or Tenable LCE agents. 

## Usage
1. Provide credentials to ElasticSearch through the `$ES_username` and `$ES_password` variables
2. Provide all available ElasticSearch hosts through the `$ES_host` array variable
3. Specify the target `$ES_index` and document `$ES_type`
4. Specify all Windows servers to collect event logs from through `$targetServers` array variable
5. Specify the Event Log name (i.e. Security) to collect in the `$filterTable` variable
6. Specify the desired `$event_interval` to collect logs. Ensure this is roughly the same frequency of script execution (i.e. in Task Scheduler)
7. Run the script, or set up in Task Scheduler


