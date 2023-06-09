# Data Schema for Influx DB Buckets

This page describes the individual data schemas used for the different buckets of the Hybrid-Car-Consumption-Monitor Influx database.

- [Data Schema for Influx DB Buckets](#data-schema-for-influx-db-buckets)
  - [Car\_Charging](#car_charging)
  - [Car\_Status](#car_status)
  - [Car\_Trips](#car_trips)
  - [Car\_Consumption](#car_consumption)
  - [Car\_Monthly](#car_monthly)

## Car_Charging

Entries in this bucket are created by the [Charging Observer](./setupChargingObserver.md) service which "measures" energy and power supplied by the charging device.

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
| "location"      | Location of the charging device.<br/>When Charging with an "observed" device, this will be set to "CarCharger".<br/>For charging with external charging stations, their location could be used.
| "sublocation"   | This field needs to contain the Vehicle Identification Number (VIN) by which a car is uniquely identified.
| "state"         | State of the device: 0=Off, 1=On

## Car_Status

Entries in this bucket are created by the [Car Observer](./setupCarObserver.md) which receives data from the manufacturers cloud services.
Car Status information is separated from trip information because a different retention period may be intended for both.

|Data Element     |Description
|-----------------|-----------
| _time           | timestamp when data is written to InfluxDB. Time of measurement
| _measuerement   | "carStatus"
| **field Keys**  |
| fuelLevel       | percentage of fuel filling
| stateOfCharge   | percentage of charging of HV battery
| batteryEnergy   | energy currently charged in the HV battery (entered by task [HCCM_EnergyBat](./createInfluxTasks.md))
| mileage         | current mileage
| **field value** |
| _value          | measured value depending on field
| **tag keys**    |
| vin             | Car ID (vehicle identification number)

## Car_Trips

Entries in this bucket are created by the [Car Observer](./setupCarObserver.md) which receives data from the manufacturers cloud services.
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
Car_Consumption entries are created by several Influx tasks (see [Creation of Influx Tasks](./createInfluxTasks.md))

|Data Element            |Description
|------------------------|-----
| _time                  | timestamp when a consumption period has ended.<br/>For ecxample end of a trip or end of a charging period.
| _measuerement          | "consumption"
| **field keys**         |
| energy                 | for decharging or charging of electric energy
| startcharging          | for charging of electric energy. Specifies the time (as int in ns) when charging started
| fuel                   | for fuel consumption
| **field value**        |
| _value                 | value depending on field
| **tag keys**           |
| vin                    | Car ID (vehicle identification number)
| process                | The process tag may take different values, depending on the field key<br/>- for energy consumption: "charge" or "decharge"<br/>- for fuel consumption: "engine"
| source                 | The Source of consumption may be different depending on the process<br/>- for process=decharge: "tripElectric" for purely electric trips or "tripMixed" for trips with fuel consumption<br/>- for process=engine: only "tripMixed"<br/>- for process=charge:  Location of charging device

## Car_Monthly

This bucket hosts statistical data aggregated on a monthly level.
Car_Monthly entries for the current month are created and updated cyclically every hour by Influx task HCCM_StatsCurMonth tasks (see [Creation of Influx Tasks](./createInfluxTasks.md))
After the end of a month, task HCCM_StatsMonth does a final update for the entire previous month.

|Data Element                                 |Description
|-------------------------------------------|-----
| _time                                     | timestamp for end of month
| _measuerement                             | "measurement"
| **field keys**                            |
|tripsTotal                                 | Total number of trips
|tripsElectric                              | Number of purely electric trips
|tripsElectricChargeCycles                  | Number of trips associated with an elecric charge cycle.<br/>An "electric charge cycle" is a completed charging process where all preceeding trips where purely electric.<br/>This is the basis for calculation of electric energy consumption for purely electric trips.
|mileageTotal                               | Total mileage (km) within the month
|mileageElectric                            | Mileage for purely electric trips within the month
|mileageElectricChargeCycles                | Mileage (km) for all (purely electric) trips associated with electric charge cycles
|traveltimeTotal                            | Total travel time (h) within the month.
|traveltimeElectric                         | Total travel time (h) for purely electric trips within the month.
|fuelConsumed                               | Fuel consumed (l) within the month.
|electricEnergyConsumedTotal                | Total electric energy (kWh) consumed within the month according to the car display.
|electricEnergyConsumedElectric             | Electric energy (kWh) consumed for purely electric trips according to the car display
|electricEnergyConsumedElectricChargeCycles | Electric energgy (kWh) consumed for trips associated with electric charge cycles according to the car display.
|chargeCyclesTotal                          | Total number of charging cycles within the month.
|chargeCyclesElectric                       | Total number of electric charge cycles within the month.
|electricEnergyChargedTotal                 | Total electric energy (kWh) charged within the month.
|electricEnergyChargedElectric              | Total electric energy (kWh) charged in electric charge cycles within the month.
| **field value**                           |
| _value                                    | value depending on field.
| **tag keys**                              |
| vin                                       | Car ID (vehicle identification number)
