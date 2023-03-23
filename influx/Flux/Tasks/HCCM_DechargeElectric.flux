//=============================================================================================================
// This function analyzes the short term trips with respect to electric energy consumption
// Keep in mind that this will be the energy consumption according to car display and not the real consumption
// Only purely electric trips are considered
// For each trip, a measurement entry is made in bucket Car_Consumption
// In order to assure that this is done only after a charging process has been finished,
// the drop of charging power is sensed
//
// This is limited to a single car, for which the Vehicle Identification Number must be spezified below
//=============================================================================================================
import "timezone"
import "date"
import "array"

option task = {name: "HCCM_DechargeElectric", every: 5m}

option location = timezone.location(name: "Europe/Berlin")

// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"

// For testing purposes, tStop may be set to a time shortly after a charging process has ended
//tStop = 2023-03-22T12:30:00Z
tStop = now()

// This is the period used for sensing power drop for charging
// It must be at least twice the sampling period used for device measurements
// It must be less than the shortest possibe charging duration
periodSensing = 20m

// This is the period used for gathering charging processes
periodProcesses = 2d

// This is the threshold used for sensing the end of a charging process.
// Typically half the charging power (~2 kW)
chargingThreshold = 1000

// ===================================================================================================
// This function checks whether the chosen stop time is after the end of a charging period
// ===================================================================================================
chargingFinished = () => {
    tStart = date.sub(from: tStop, d: periodSensing)

    powerData =
        from(bucket: "Car_Charging")
            |> range(start: tStart, stop: tStop)
            |> filter(fn: (r) => r["_measurement"] == "power")
            |> filter(fn: (r) => r["sublocation"] == vin)

    powerDataFirst =
        powerData
            |> first()
    powerDataFirstRec =
        powerDataFirst
            |> findRecord(fn: (key) => key._measurement == "power" and key._field == "value", idx: 0)
    p0 = powerDataFirstRec["_value"]

    powerDataLast =
        powerData
            |> last()
    powerDataLastRec =
        powerDataLast
            |> findRecord(fn: (key) => key._measurement == "power" and key._field == "value", idx: 0)
    p1 = powerDataLastRec["_value"]

    ret = if p0 > chargingThreshold and p1 < chargingThreshold then true else false

    return ret
}

// ===================================================================================================
// Analyze the short term trips to get the electric energy consumed
// Here, only purely electric trips are considered
// ===================================================================================================
consumptionElectricFromTrips = () => {
    tStart = date.sub(from: tStop, d: periodProcesses)

    ret =
        // Get all shortTerm trips for the given car within the given time range
        from(bucket: "Car_Trips")
            |> range(start: tStart, stop: tStop)
            |> filter(fn: (r) => r["_measurement"] == "trip_shortTerm")
            |> filter(fn: (r) => r["vin"] == vin)
            // Get rid of unnecessary columns
            |> drop(
                columns: [
                    "_measurement",
                    "_start",
                    "_stop",
                    "vin",
                    "reportReason",
                    "tripID",
                ],
            )
            // Pivot with respect to _time to get a table with rows based on _time and data as columns
            |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
            // We need to make sure that the table is sorted with respect to _time
            |> sort(columns: ["_time"])
            // The Car_Trips bucket includes all partial trips for which data are accumulated into the latest.
            // Whereas WeConnect finally keeps only the latest trip of a group, we also keep the partial trips
            // as long as they have been received from WeConnect before the entire trip has been "closed"
            // by a gap of at least 2 hours
            // All partial trips of a trip have the same "startMileage"
            // We only need to keep the last one
            |> group(columns: ["startMileage"])
            |> tail(n: 1)
            // Now that we have a table of all trips within the relevant time range, 
            // we only keep the purely electric ones.
            // tripMileage>0 is added because sometimes very short trips are registered with tripMileage=0
            // (WeConnect reports only integer mileage values). This would cause devision errors
            |> filter(fn: (r) => r["fuelConsumed"] == 0 and r["tripMileage"] > 0)
            // Some more columns are no longer required.
            // We only keep electricPowerConsumed
            |> drop(
                columns: [
                    "startMileage",
                    "endMileage",
                    "fuelConsumed",
                    "traveltime",
                    "tripMileage",
                ],
            )
            // Now, we add the columns required for car_Consumption
            |> set(key: "_measurement", value: "consumption")
            |> set(key: "process", value: "decharge")
            |> set(key: "source", value: "tripElectric")
            |> set(key: "vin", value: vin)

    return ret
}

cf = chargingFinished()

// This is a "Null" table which is required later in the Flux if statement
consNul =
    array.from(
        rows: [
            {
                _time: 1900-01-01T00:00:00Z,
                _measurement: "consumption",
                process: "charge",
                source: "home",
                vin: "000000000000",
                electricPowerConsumed: 0.0,
            },
        ],
    )

// A consumption entry shall only be created after charging has been finished.
// This guarantees that the latest trip is "closed"
// and consumtion entries are not created for partial trips
cons = if chargingFinished() then consumptionElectricFromTrips() else consNul

// Now the entries in Car_Consumption for the relevant trips are created
cons
    |> to(
        bucket: "Car_Consumption",
        timeColumn: "_time",
        measurementColumn: "_measurement",
        tagColumns: ["process", "source", "vin"],
        fieldFn: (r) => ({"energy": r.electricPowerConsumed}),
    )
