# Creation of Influx Tasks

Transformation of raw data obtained from Charging Observer and Car Observer into structures used for evaluation is done through Influx Tasks.
These tasks run on specific schedules. They read data from input buckets and write transformed data to output buckets.
For more information on the data schema for the different buckets, see [Data Schema for Influx DB Buckets](./influxDBDataSchema.md)

## Overview

The following diagram shows all tasks with their related buckets.

![Influx Task Overview](img/HCCM_DB.jpg)
