# Setup of Grafana for Hybrid-Car-Consumption-Monitor

For Grafana documentation, see [https://grafana.com/grafana/](https://grafana.com/grafana/).

## 1. Installation of Grafana

If Grafana is already available in your environment, you may decide to use this instance to add the additional dashboards required for the Hybrid-Car-Consumption-Monitor.

Otherwise, follow a suitable process described in [Download Grafana](https://grafana.com/grafana/download?pg=get&plcmt=selfmanaged-box1-cta1).
It is recommended to use a Docker-based installation.

The following steps describe the docker-based installation

|Step|Action
|----|-----------------------------------------------------
|1.  | Make sure that Docker is running on the system to be used as server (see [Get Docker](https://docs.docker.com/get-docker/))
|2.  | Create a directory to be used for data storage outside the Grafana container, e.g. ```$ROOT/docker/grafana``` with an arbitrary root directory ```$ROOT```<br/>Note that Grafana runs per default with uid/gid 472 (see [Run Grafana Docker Image](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)). Therefore, the directory requires these access rights. On a Linux system, set these with ```sudo chown -R 472:472 grafana``` from within the ```$ROOT/docker``` directory.
|3.  | Download and run latest version of Grafana:<br/>```docker run --detach --name=grafana -p 3000:3000 --volume $ROOT/docker/grafana:/var/lib/grafana grafana/grafana:latest```<br/>As a result, the container ID will be displayed and a running ```grafana``` container will be shown on the Docker UI Container page.<br/><br/>If container start fails because of access rights, try<br/>```docker run --detach --name=grafana -p 3000:3000 grafana/grafana:latest```

## 2. Initial Configuration

|Step|Action
|----|-----------------------------------------------------
|4.  | Open the Grafana UI through <br/> ```http://<server>:3000``` <br/> where ```<server>``` is the network name of your server or 'localhost'
|5.  | Log in with the initial user/password: ```admin```/```admin```
|6.  | On the next page enter a new password for the admin account
|7.  | Open the ```Configuration/Data sources``` page
|8.  | Select the InfluxDB entry
|9.  | On the next page specify the following settings 
|    | **Name**: a name by which the InfluxDB shall be identified. Usually ```InfluxDB```.
|    | **Query Language**: ```Flux```
|    | **URL**: ```http://<server>:8080```<br/>**Note**: If Grafana is running as Docker container, you should not use ```localhost``` as server name because this would refer to the container.
|    | **Auth**: Deactivate all entries
|    | InfluxDB Details:<br/>**Organization**: ```HCCM```<br/>**Token**: Token obtained during [Setup InfluxDB](setupInfluxDb.md) Step 3<br/>**Default Bucket**: ```Car_Status```
|10. | Press ```Save & Test```
|11. | Under ```Configuration / Users``` you may create a new user with a specific role by invitation
|12. | Under ```Configuration / Teams``` you may create a team and add users<br/>This has the advantage that Preferences like language, time zone or UI theme can be configured.

## 3. Import Dashboards

Car-Consumption-Monitor includes a set of dashboards which need to be imported into Grafana.
JSON files for each dashboard are located at ```./grafana/Dashboards```.
The files have a language suffix indicating the UI language used for the dashboard.

|Step|Action
|----|-----------------------------------------------------
|13. | Open the Grafana UI
|14. | Open page ```Dashboards/Browse```
|15. | Push the ```New``` button and then select ```Import``` and then ```Upload Dashboard JSON file```
|16. | Navigate to ```./grafana/Dashboards``` and select the dashboard to be imported and push ```Import```

