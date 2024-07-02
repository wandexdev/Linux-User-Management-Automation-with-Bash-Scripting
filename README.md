![Process Overview](images/hng-bash-banner.png)

## Scenario:
As a **SysOps or SysAdmin Engineer**, you are tasked with onboarding new engineers on most of the company's Linux servers. Users, groups, and home directories would be created. Access permissions for each user following the rule of less privilege should be observed. It would be inefficient to do so manually, looking at the number of servers and new engineers to be onboarded.
> *I have created a script that meets the basic requirements and some more. Check my [article](https://dev.to/wandexdev/automation-onboard-new-engineers-on-linux-with-best-practice-bashshell-scripting-121o) here for a detailed walk through* 
>
>*It puts measures in place for errors while running the script, creates secure files to store user lists and passwords, creates files to debug and log processes, and finally sends notifications on both the terminal and Slack, all while following best practices.*

## Usage:
- Clone the `create_users.sh` script from this [repository](https://github.com/wandexdev/Linux-User-Management-Automation-with-Bash-Scripting/blob/main/create_users.sh)to your **ubuntu server**,
- Execute the file by running `chmod +x create_users.sh`
- Assemble the input file which is the argument, formatted this way as shown below: usernames are differentiated by a semicolon, and groups are differentiated by a comma
```txt
adebare; admin,dev,qa
bolade; prod
chibuzor; test,dev,prod
tunde; pilot,prod,test,dev
tade; pilot,dev
```
- save the input file as `text.txt`
- Run script with `sudo` via `sudo bash create_users.sh text.txt`
