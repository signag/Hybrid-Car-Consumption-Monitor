# Data Schema for Influx DB Buckets

This page describes the individual data schemas used for the different buckets of the Hybrid-Car-Consumption-Monitor Influx database.

## Car_Charging

Entries in this bucket are created by the Charging Observer service which "measures" energy and power of the charging device.

|Data Element     |Description
|-----------------|----------------------------
| _time           | timestamp when data is written to InfluxDB. Time of measurement.
| _measuerement   | "power", "energy"
| **field Keys**  |
| _field          | "value"
| **field value** |
| _value          | measured value of power or energy received from Fritz!Box
| **tags**        |
| "ain"           | Actor identification number of the device<br/>This is just for information and can be used to distinguish different charging devices (e.g. home and external) being used to charge a car.<br/>When charging through a Fritz!Dect smart power outlet, this is the ain of the device.
| "location"      | Location of the charging device.<br/>When Charging with an "observed" device, this will be set to "CarCharger".<br/>For charging with external charging stations, theit location could be used.
| "sublocation"   | This field needs to contain the Vehicle Identification Number (VIN) by which a car is uniquely identified.
| "state"         | State of the device: 0=Off, 1=On

## Car_Status

Entries in this bucket are created by the Car Observer which receives data from the manufacturers cloud services.
Car Status information is separated from trip information because a different retention period may be intended for both.

|Data Element     |Description
|-----------------|-----------
| _time           | timestamp when data is written to InfluxDB. Time of measurement
| _measuerement   | "carStatus"
| **field Keys**  |
| fuelLevel       | percentage of fuel filling
| stateOfCharge   | percentage of charging of HV battery
| mileage         | current mileage
| **field value** |
| _value          | measured value depending on field
| **tag keys**    |
| vin             | Car ID (vehicle identification number)

## Car_Trips

Entries in this bucket are created by the Car Observer which receives data from the manufacturers cloud services.
Trip information is usually retained for a larger period than car status information.

|Data Element            |Description
|------------------------|-----
| _time                  | timestamp when trip was ended
| _measuerement          | "trip_shortTerm"
| **field keys**         |
| startMileage           | Mileage at trip start
| tripMileage            | Mileage for the trip
| travelTime             | Travel time (min) for trip
| fuelConsumed           | Fuel consumed (l) for trip
| electricPowerConsumed  | Electric energy consumed (kWh)
| **field value**        |
| _value                 | measured value depending on field
| **tag keys**           |
| vin                    | Car ID (vehicle identification number)
| tripID                 | We-Connect-internal ID for the trip (just for information)
| reportReason           | We-Connect-internal reason for the trip  (just for information)

## Car_Consumption

This bucket hosts all data for consumption, be it fuel or electric energy. Also charging is included which is considered as a kind of negative consumption.

|Data Element            |Description
|------------------------|-----
| _time                  | timestamp when a consumption period has ended.<br/>For ecxample end of a trip or end of a charging period.
| _measuerement          | "consumption"
| **field keys**         |
| energy                 | for decharging or charging of electric energy
| fuel                   | for fuel consumption
| **field value**        |
| _value                 | value depending on field
| **tag keys**           |
| vin                    | Car ID (vehicle identification number)
| process                | The process tag may take different values, depending on the field key<br/>for energy consumption: "charge" or "decharge"<br/>For fuel consumption: "engine"
| source                 | The Source of consumption may be different depending on the process<br/>For energy decharge: "tripElectric" for purely electric trips or "tripMixed" for trips with fuel consumption<br/>For fuel consumption: only "tripMixed"<br/>For energy charge "consumption":  Location of charging device
