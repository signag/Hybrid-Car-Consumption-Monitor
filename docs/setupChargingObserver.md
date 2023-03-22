# Setup of Charging Observer

The Charging Observer is a service which cyclically queries the car charging device for current power and stores the measured values in the InfluxDB.

The service to be used depends on the device type.

## Device Type Fritz!Dect 2x0 on Fritz!Box

Fritz!Box allows to programmatically query connected Dect Home Automation devices for live measurement data.
We use [fritzToInfluxHA](https://github.com/signag/fritzToInfluxHA) to observe a Fritz!Dect 210 device through which the car is charged.
Measurement data will be stored in Influx Bucket ```Car_Charging```

|Step|Action
|----|-----------------------------------------------------
|1.  | Select a suitable Linux machine with Python 3.7 or later, having access to the Fritz!Box on one side and to the InfluxDB server on the other.<br/>The current setup uses a Raspberry Pi 4
|2.  | Install **fritzToInfluxHA** (```[sudo] pip install fritzToInfluxHA```)
|3.  | On the Fritz!Box configure a specific user with Smart Home permission. It is recommended not to allow internet access.
|4.  | Create and stage configuration file for **fritzToInfluxHA** (see [Configuration](#configuration))
|5   | Adjust the service configuration file, if required. Especially check python path and user (see [Service](#service))
|6.  | Stage configuration file: ```sudo cp fritzToInfluxHA.service /etc/systemd/system```
|7.  | Start service: ```sudo systemctl start fritzToInfluxHA.service```
|8.  | Check log: ```sudo journalctl -e``` should show that **fritzToInfluxHA** has successfully started
|9.  | In case of errors adjust service configuration file and restart service
|10. | To enable your service on every reboot: ```sudo systemctl enable fritzToInfluxHA.service```

### Configuration

A configuration file "fritzToInfluxHA.json" shall be staged under ```$HOME/.config```
In the following template the entries in ```<...>``` need to be replaced by their correct values.

```json
{
    "measurementInterval": 120,
    "FritzBoxURL" : "http://fritz.box/",
    "FritzBoxUser" : "<FritzBoxMonitorUser>",
    "FritzBoxPassword" : "<FritzBoxMonitorUserPassword>",
    "InfluxOutput" : true,
    "InfluxURL" : "http://<InfluxServer>:8086",
    "InfluxOrg" : "HCCM",
    "InfluxToken" : "<InfluxToken>",
    "InfluxBucket" : "Car_Charging",
    "csvOutput" : false,
    "csvFile" : "",
    "devices" : [
        {
            "ain" : "<actorIdentificationNumber>",
            "location" : "CarCharger",
            "sublocation" : "<Vehicle Identification Number>",
            "measurements" : {
                "voltage" : false,
                "power" : true,
                "energy" : true,
                "temperature" : false
            }
        }
    ]
}
```

### Parameters

| Parameter            | Description
|----------------------|------------------------------------------------------------------------------------------------------
| measurementInterval  | Measurement interval in seconds. (Default: 120) (Note that the Fritz!Box will updata data only every 2 min.)
| FritzBoxURL          | URL of the Fritz!Box (Default: "http://fritz.box/")
| FritzBoxUser         | User to be used for FritzBox access. Needs th have "Smart Home" permission
| FritzBoxPassword     | Password for Fritz!Box user
| InfluxOutput         | Specifies whether measurement shall be stored in InfluxDB (Needs to be set to true)
| InfluxURL            | URL for access to Influx DB
| InfluxOrg            | Organization Name specified during [InfluxDB installation](setupInfluxDb.md) Step 2
| InfluxToken          | Influx API Token (see [InfluxDB installation](setupInfluxDb.md) Step 3)
| InfluxBucket         | Bucket to be used for storage of measurements (Needs to be set to ```Car_Charging```)
| csvOutput            | Specifies whether measurement data shall be written to a csv file (Default: false)
| csvFile              | Path to the csv file (Only required if cvsOutput=true)
| **devices**          | List of devices to be monitored. Here only the Fritz!Dect 2x0 used for charging needs to be listed
| - ain                | Actor Identification Number of the device. It is printed on the device and can be shown in the Fritz!Box
| - location           | Location where the device is located. The entry is just for information and can be arbitrarily chosen.
| - sublocation        | This needs to be the Vehicle Identification Number (VIN) of the car being charged at this device. The VIN also identifies the car in the manufacturers cloud services (VW WE Connect)
| - **measurements**   | List of measurements to be performed. For this purpose, only power is required
| -- voltage           | Specifies whether voltage shall be measured (false)
| -- power             | Specifies whether power shall be measured (true)
| -- energy            | Specifies whether enrgy shall be measured (true)
| -- temperature       | Specifies whether temperature shall be measured (false)

### Service

A service configuration file "fritzToInfluxHA.service" can be initially staged for editing under ```$HOME/.config```

```code
[Unit]
Description=FritzToInfluxHA
After=network.target

[Service]
ExecStart=/usr/bin/python3 -u fritzToInfluxHA.py -s
WorkingDirectory=/usr/local/lib/python3.7/dist-packages/fritzToInfluxHA
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```
