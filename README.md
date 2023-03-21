# Hybrid-Car-Consumption-Monitor

This monitoring system can be used for gathering and visualization of car consumption data, especially for hybrid cars.

The system uses two sources of input:

1. The car charging system, which is, in its simplest version, a metered power outlet from which charging power over time is obtained.
2. Car and trip data from the car manufacturer's cloud services, which needs to provide information on trip start time, trip duration, mileage, electric energy consumption as well as fuel consumption.
Furthermore, fuel as well as battery fill level are also expected.

From these data, the monitor calculates and aggregates various consumption KPIs and allows tracking these over an arbitrary period of time.

## Prerequisites

A number of prerequisites are required for this system which are graphically shown in the [Architecture Overview](docs/architecture.md).
This documentation assumes a specific configuration, which will be detailed below, but the general approach is not limited to this and can be extended to other configurations.

### 1. Smart Car Charging System

Monitoring the charging process requires a charging system with an interface through which access to the current charging power is available.

In the current setup, a Volkswagen VW Passat GTE (model 2018) is charged through a normal power outlet.
A smart plug [Fritz!DECT210](https://en.avm.de/products/smart-home/fritzdect-210/) is used in connection with a [Fritz!Box](https://en.avm.de/products/fritzbox/) to track the charging power over time.

### 2. Access to Live Car Data

Most car manufacturers provide access to car data through specific cloud services.

The current setup for Volkswagen uses access through [WE Connect](https://www.volkswagen-nutzfahrzeuge.de/de/digitale-dienste-und-apps/we-connect.html) for which a registration is required.
(The above link is for Germany. Similar links are available for other countries)

### 3. 24/7 Server

The server hosts installations of the time series database [InfluxDB](https://www.influxdata.com/products/) as well as the analytics and monitoring solution [Grafana](https://grafana.com/). For both tools, cloud solutions as well as local docker or native installations are available.

In the current setup, both tools run in docker containers on a Synology [DS220+](https://www.synology.com/de-de/products/DS220+)

### 4. 24/7 Data Collection System

The data collection system hosts observer services for car charging as well as for car live data.

In the current setup, these are implemented in Python and run on a [Rspberry Pi 4](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)

## Setup

1. [Setup InfluxDB](https://github.com/signag/Hybrid-Car-Consumption-Monitor/blob/main/docs/setupInfluxDb.md)
2. [Setup Charging Observer](./docs/setupChargingObserver.md)
3. 