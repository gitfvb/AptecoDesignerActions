# Description

* This script helps to go through all databases and shrink them.
* If you want sqlscripts to be executed, you can put them in the `sql` subfolder
* If you want sqlscripts to be executed on databases with a specific prefix like `ws_handel` and `ws_reisen`, put them in a subfolder like `sql\prefix_ws`. Then those scripts will be executed for every `ws*` database
* The scripts use trusted connection by default and that refers to the user that starts this script (could be a scheduled task or a process like 'Designer'). Be aware of the user.

# Hints

* Check the $settings object in the file and replace it with your sqlserver instance and maybe other databases