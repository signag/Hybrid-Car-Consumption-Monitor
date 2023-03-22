# Setup of Car Observer

The Car Observer is a service which cyclically queries car status data through the manufacturers cloud services and stores the measured values in the InfluxDB.

The service to be used depends on the services available to read out car data.

## Volkswagen WeConnect

Wit [WeConnect](<https://www.volkswagen-nutzfahrzeuge.de/de/digitale-dienste-und-apps/we-connect.html>), Volkswagen offers cloud services to access various status data from a car.

For cyclic data collection and storaging in InfluxDB, we use the [monitorVW](https://github.com/signag/monitorVW) implementation, which makes use of the [weconnect](https://github.com/trocotronic/weconnect) interface implementation.

Car status data will be stored in Influx Bucket ```Car_Status``` whereas trip data will be stored in ```Car_Trips```

To get access to WeConnect, you require a registration with username and password as well as the 4-digit security pin which is specified in the mobile WeConnect App.

|Step|Action
|----|-----------------------------------------------------
|1.  | Select a suitable Linux machine with Python 3.7 or later, having access to the internet on one side and to the InfluxDB server on the other.<br/>The current setup uses a Raspberry Pi 4
|2.  | Install **monitorVW** (```[sudo] pip install monitorVW```)
|4.  | Create and stage configuration file for **monitorVW** (see [Configuration](#configuration))
|5   | Adjust the service configuration file, if required. Especially check python path and user (see [Service](#service))
|6.  | Stage configuration file: ```sudo cp monitorVW.service /etc/systemd/system```
|7.  | Start service: ```sudo systemctl start monitorVW.service```
|8.  | Check log: ```sudo journalctl -e``` should show that **monitorVW** has successfully started
|9.  | In case of errors adjust service configuration file and restart service
|10. | To enable your service on every reboot: ```sudo systemctl enable monitorVW.service```

### Configuration

A configuration file "monitorVW.json" shall be staged under ```$HOME/.config```
In the following template the entries in ```<...>``` need to be replaced by their correct values.

```json
{
    "measurementInterval": 1800,
    "weconUsername": "<weconUser>",
    "weconPassword": "<weconPwd>",
    "weconSPin": "<weconPin>",
    "weconCarId": "<weconCarID>",
    "InfluxOutput": true,
    "InfluxURL": "http://<InfluxServer>:8086",
    "InfluxOrg": "HCCM",
    "InfluxToken": "<InfluxToken>",
    "InfluxBucket": "Car_Status",
    "InfluxTripBucket": "Car_Trips",
    "csvOutput": false,
    "csvFile": "",
    "carData": {
        "tripDataShortTerm": {
            "InfluxOutput": true,
            "InfluxMeasurement": "tripShortTerm",
            "InfluxTimeStart": "",
            "InfluxDaysBefore": "5",
            "csvOutput": true,
            "csvFile": ""
        },
    }
}
```


### Parameters

| Parameter               | Description
|-------------------------|-------------------------------------------------------------
| measurementInterval     | Measurement interval in seconds. (Default: 1800)
| weconUsername           | User name of Volkswagen WE Connect registration
| weconPassword           | Password of Volkswagen WE Connect registration
| weconSPin               | The 4-digit security pin which is specified in the mobile We Connect App
| weconCarId              | Vehicle Identification Number (VIN/FIN) as shown for cars registered in WE Connect
| InfluxOutput            | Specifies whether data shall be stored in InfluxDB (must be true)
| InfluxURL               | URL for access to Influx DB
| InfluxOrg               | Organization Name specified during InfluxDB installation
| InfluxToken             | Influx API Token (see [InfluxDB installation](setupInfluxDb.md) Step 3)
| InfluxBucket            | Bucket to be used for storage of car status data (Must be "Car_Status")
| InfluxTripBucket        | Bucket to be used for storage of car trip data (Must be "Car_Trips")
| csvOutput               | Specifies whether car data shall be written to a csv file (Default: false)
| csvFile                 | Path to the csv file if cvsOutput=true
| **carData**             | list of car data to be considered. Here, only the short term trip data are relevant
| - **tripDataShortTerm** | Short term trip data (includes every individual trip)
| -- InfluxOutput         | Specifies whether trip data shall be written to InfluxDB (Must be true)
| -- InfluxMeasurement    | Measurement to be used for this kind of trip data (Must be "tripShortTerm")
| -- InfluxTimeStart      | Start date from which on trips shall be included (default: 01.01.1900)
| -- InfluxDaysBefore     | Number of days before current date from which on trips shall be included (default: 9999) (later of both is uesd)<br/>Setting this to a few days only, guarantees that the program will not download the entire trip history in every run.
| -- csvOutput            | Specifies whether these trip data shall be written to a cvs file. (Normally false)
| -- csvFile              | File path to which these trip data shall be written. Only required if cvsOutput=true
| - **tripDataLongTerm**  | Long term trip data (aggregated trip data for longer periods (Not required))
| - **tripDataCyclic**    | Aggregated trips from one fill-up to the next (Not required)

### Service

A service configuration file "monitorVW.service" can be initially staged for editing under ```$HOME/.config```

```code
[Unit]
Description=monitorVW
After=network.target

[Service]
ExecStart=/usr/bin/python3 -u monitorVW.py -s
WorkingDirectory=/usr/local/lib/python3.7/dist-packages/monitorVW
StandardOutput=inherit
StandardError=inherit
Restart=always
User=sn

[Install]
WantedBy=multi-user.target
```
