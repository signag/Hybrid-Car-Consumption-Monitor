# Setup of the Influx DB for Hybrid-Car-Consumption-Monitor

For InfluxDB OSS documentation, see [https://docs.influxdata.com/influxdb/v2.6/#](https://docs.influxdata.com/influxdb/v2.6/#) and make sure that the selected version is the latest available.

## 1. Installation of Influx DB OSS

If Influx DB OSS is already available in your environment, you may decide to use this instance to add the additional infrastructure required for Hybrid-Car-Consumption-Monitor.

Otherwise, follow a suitable process described in [Install InfluxDB](https://docs.influxdata.com/influxdb/v2.6/install/).
It is recommended to use a Docker-based installation.

The following steps describe the docker-based installation

|Step|Action
|----|-----------------------------------------------------
|1.  | Make sure that Docker is running on the system to be used as server (see [Get Docker](https://docs.docker.com/get-docker/))
|2.  | Create a directory to be used for data storage outside the influxDB container, e.g. ```$ROOT/docker/influxdb``` with an arbitrary root directory ```$ROOT```
|3.  | Create a directory to be used for configuration storage outside the influxDB container, e.g. ```$ROOT/docker/influxdb_configs```
|4.  | Download and run latest version of influxDB:<br/>```docker run --detach --name influxdb -p 8086:8086 --env TZ=Europe/Berlin --volume $ROOT/docker/influxdb:/var/lib/influxdb2 --volume $ROOT/docker/influxdb-configs:/etc/influxdb2/influx-configs influxdb:latest --reporting-disabled```<br/> You will need to replace ```ROOT``` by your root directory and set the correct timezone variable ```TZ```. <br/> As a result, the container ID will be displayed and a running ```influxdb``` container will be shown on the Docker UI Container page.

## 2. Initial Configuration

|Step|Action
|----|-----------------------------------------------------
|5.  | Open the InfluxDB UI through <br/> ```http://<server>:8086``` <br/> where ```<server>``` is the network name of your server or 'localhost'
|6.  | On the Welcome page press ```GET STARTED```
|7.  | On the next page enter the requested information and press ```CONTINUE```. For the configuration examples in this documentation, the following settings are assumed: <br/>Username: ```influxAdmin```<br/>Password: ```influxPwd```<br/>Initial Organization Name: ```HCCM```<br/>Initial Bucket Name: ```Car_Status```
|8.  | On the following page, press ```QUICK START```
|9.  | Create additional buckets required for Hybrid-Car-Consumption-Monitor.<br/>First open ```Buckets``` under ```Load Data``` and create the following buckets using the ```CREATE BUCKET``` button:<br/>Car_Charging<br/>Car_Consumption<br/>Car_Monthly<br/>Car_Status<br/>Car_Trips<br/><br/>Initially, leave ```Delete Data``` at ```NEVER```

## 3. Memorize and Configure API Token

The API Token will be used to gain access to the different buckets from the Data Collection Services as well as from Grafana. Since access to the token is possible only while it is being created, it is recommended to save it at a separate location for later use.

|Step|Action
|----|-----------------------------------------------------
|10. | In the InfluxDB Web UI, open ```API Tokens``` under ```Load Data```
|11. | Remove the ```influxAdmin's Token```
|12. | Press ```GENERATE API TOKEN``` and then choose ```All Access API Token``` and give it the name ```influxToken```<br/>To be more restrictive, you may also choose ```Custom API Token``` and then confirm Write access to all Buckets previously created.<br/>Before you close the confirmation dialog, make sure to copy the API key and store it for later access.

## 4. Set up the Influx CLI

The Command Line Interface is usefull for accessing Influx from the command line.
The CLI will usually be installed on your working system, be it Windows, Mac or Linux.

|Step|Action
|----|-----------------------------------------------------
|13. | Follow the instructions under [Install and use the influx CLI](https://docs.influxdata.com/influxdb/v2.6/tools/influx-cli/) for installation.
|14. | To provide required authentication credentials for the CLI, execute the following influx command on the command line of the system where the CLI was installed:<br/>```influx config create --config-name cfgHCCM --host-url http://<server>:8086 --org HCCM --token <influxToken> --active```<br/>where ```<server>``` needs to be replaced by the server name and ```<influxToken>``` by the token obtained in step 3.<br/>See [influx config](https://docs.influxdata.com/influxdb/v2.6/reference/cli/influx/config/) for details on the command.
|15. | Execute CLI command<br/>```influx bucket list```<br/>to verify that the Influx CLI works correctly for the installed database.
