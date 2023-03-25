# Specify Prices

Some charts refer to prices for electricity and/or fuel.
These are stored car-specific on a monthly base in bucket ```Car_Monthly```

For price specification, a FLUX script is available under ```./influx/Commands/Car_Prices.flux```

The script can be run form VS Code using the [Flux VS Code extension](https://docs.influxdata.com/influxdb/v2.6/tools/flux-vscode/#Copyright)

Alternatively, the script can be run as a Notebook within the Influx UI:

| Step | Description
|------|----------
| 1.   | Open the Influx UI
| 2.   | Open page ```Notebooks```
| 3.   | Choose ```Write a Flux Script```
| 4.   | Paste the entire content of ```Car_Prices.flux``` to section ```Query to run```
| 5.   | If you do not want to run the script for the current month, specify the month offset
| 6.   | Adjust the prices for fuel, electricity as well as the car Vehicle Identification Number ```VIN```
| 7.   | Push the ```RUN``` button
| 8.   | Check the result in section ```Validate the data```