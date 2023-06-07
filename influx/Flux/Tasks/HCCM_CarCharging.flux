//=============================================================================================================
// This function analyzes the energy for car charging to identify individual charging processes
// For each charging process, a measurement entry is made in bucket Car_Consumption
// In order to assure that this is done only after a charging process has been finished,
// the drop of charging power is sensed
// 
// This is limited to a single car, for which the Vehicle Identification Number must be spezified below
//=============================================================================================================
import "timezone"
import "date"
import "array"

option task = {name: "HCCM_CarCharging", every: 5m}

option location = timezone.location(name: "Europe/Berlin")

// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// For testing purposes, tStop may be set to a time shortly after a charging process has ended
tStop = now()
//tStop = 2023-03-22T12:30:00Z

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
// Analyze the charged energy to identify the different charging events
// Start of a charging event is identified by steeply rising power
// End of the charing event is identified by steeply decreasing power
// ===================================================================================================
consumptionFromCharging = () => {
    tStart = date.sub(from: tStop, d: periodProcesses)

    calc =
        from(bucket: "Car_Charging")
            // Get the energy captured for the Fritz! HA device used for charging
            |> range(start: tStart, stop: tStop)
            |> filter(fn: (r) => r["_measurement"] == "energy")
            |> filter(fn: (r) => r["sublocation"] == vin)
            // Keep only columns required for this analysis
            |> drop(
                columns: [
                    "_measurement",
                    "ain",
                    "location",
                    "state",
                    "sublocation",
                    "_start",
                    "_stop",
                ],
            )
            // Sort with respect to _time to avoid issues with derivative
            |> sort(columns: ["_time"])
            // We are not interested in absolute overall values but only in relative increments
            |> increase()
            // Now, we differentiate the energy to get the power
            |> duplicate(column: "_value", as: "diff")
            |> derivative(unit: 1h, columns: ["diff"])
            // Measuring points indication zero power can be excluded
            |> filter(fn: (r) => r["diff"] > 0)
            // Now, we define a step function (tag) on the power, setting all values below a threshold to zero.
            |> map(fn: (r) => ({r with tag: if r.diff > 0.08 then 1 else 0}))
            // Now, we identify instances of rising and falling power
            // tag2 ==  1: rising power
            // tag2 ==  0: steady power level
            // tag2 == -1: falling power
            |> duplicate(column: "tag", as: "tag2")
            |> difference(columns: ["tag2"], nonNegative: false, keepFirst: true, initialZero: true)
            // Now, we use tag3, to identify all measuring points, related to a charging period
            // This needs to include the starting point (tag2 == 1) and the end point (tag2 == -1)
            // as well as all points with sufficiently high power level (tag == 1)
            |> map(fn: (r) => ({r with tag3: if r.tag2 == -1 then 1 else r.tag}))
            // Now, we keep only the charging periods (tag3 == 1)
            |> filter(fn: (r) => r["tag3"] == 1)
            // Now, we define tag4, which identifies all starting points of charging periods
            |> map(fn: (r) => ({r with tag4: if r.tag2 == 1 then 1 else 0}))
            // When accumulating tag4 in tag5, every charging period gets its individual value
            // because onty the starting points contribute whereas assl subsequent points of the same period don't
            |> duplicate(column: "tag4", as: "tag5")
            |> cumulativeSum(columns:["tag5"])
            // This allows grouping with respect to charging periods
            |> group(columns: ["tag5"])
            // Cumulative sum of tag will count the measuring points of a period
            // Cumulative sum of tag4 (1 only for starting points) will indicate whether a sequence is complete
            // If a sequence does not include the starting point the sum will remain zero.
            |> cumulativeSum(columns: ["tag", "tag4"])
            // Now, we define colum "start" which will contain the starting time of a charging period
            // For the starting point, it will be set to _time, for others zero
            |> map(fn: (r) => ({r with start: if r.tag2 == 1 then uint(v: r._time) else uint(v: 0)}))
            |> cumulativeSum(columns: ["start"])
            // Only the last row in each table is kept which carries the energy carged during a charging period
            // and the sum of measurement points (tag).
            // The value of tag4 indicates whether a series is complete (1) or incomplete (0)
            // because the value of 1 is only possible if a series includes a starting mark (tag2==1) for rising power
            |> tail(n: 1)
            // Now ungroup stream to get a single table
            |> group()
            // Now, we keep only the rows for suffinciently long charging periods (tag > 3)
            |> filter(fn: (r) => r["tag"] > 3)
            // Calculate start time: convert r.start from uint to int
            |> map(fn: (r) => ({r with startcharging: int(v: r.start)}))
            // _value contains the energy, charged at a certain time
            |> duplicate(column: "_value", as: "charged")
            // The energy, charged in a specific charging period is the difference between subsequent rows
            |> difference(columns: ["charged"], nonNegative: false, keepFirst: true, initialZero: true)
            |> map(fn: (r) => ({r with charged: if r.charged == 0 then r._value else r.charged}))
            // Now, we keep only the rows for complete charging periods (tag4 == 1)
            |> filter(fn: (r) => r["tag4"] == 1)
            // Drop all unnecessary columns
            |> drop(
                columns: [
                    "_value",
                    "_field",
                    "diff",
                    "tag",
                    "tag2",
                    "tag3",
                    "tag4",
                    "tag5",
                    "start",
                ],
            )
            // Add columns required for the bucket
            |> set(key: "_measurement", value: "consumption")
            |> set(key: "process", value: "charge")
            |> set(key: "source", value: "CarCharger")
            |> set(key: "vin", value: vin)
            |> set(key: "tag", value: "CALC")

    // To avoid duplicates, we check existing consumption entries
    cons =
        from(bucket: "Car_Consumption")
            // Get all KFZ_Consumption entries within the range, representing charging events
            // (_field == "energy" AND source == "home")
            |> range(start: tStart, stop: tStop)
            |> filter(fn: (r) => r["_measurement"] == "consumption")
            |> filter(fn: (r) => r["_field"] == "energy")
            |> filter(fn: (r) => r["source"] == "CarCharger")
            |> duplicate(column: "_value", as: "charged")
            // Drop unnecessary columns
            |> drop(
                columns: [
                    "_start",
                    "_stop",
                    "_value",
                    "_field",
                ],
            )
            |> set(key: "tag", value: "CONS")

    uni =
        // Union streams with new and existing charging events
        union(tables: [calc, cons])

    unis =
        uni
            // Ungroup to get all in a single table
            |> group()
            // Sort with respect to _time to get the correct sequence of new and existing charging events
            |> sort(columns: ["_time"])

    unisf =
        unis
            // We need to preserve the first record ecause elapsed will remove it
            |> first(column: "source")
            |> map(fn: (r) => ({r with tdiff: 0}))

    uniel =
        unis
            // Add column for time elapsed between events
            |> elapsed(unit: 1m, columnName: "tdiff")
    
    unin =
        // Include the first record
        union(tables: [unisf, uniel])

    unins = 
        unin
            // Sort 
            |> sort(columns: ["_time"])

    uninsg = 
        unins
            // Add tag2 for later grouping of entries within the same interval
            |> map(fn: (r) => ({r with tag2: if r.tdiff > 20 then 1 else 0}))
            // Add counter column
            |> map(fn: (r) => ({r with count: 1}))
            // cumulating sum will give the key for subsequent grouping
            |> cumulativeSum(columns: ["tag2"])
            // This allows grouping with respect to intervals
            |> group(columns: ["tag2"])
            // cumulate counter to find groups with multiple records
            |> cumulativeSum(columns: ["count"])

    uninsgt = 
        uninsg
            // Keep just the last row
            |> tail(n: 1)
            // Ungroup
            |> group()

    ret = 
        uninsgt
            // Now, filter just rows resulting from groups with a single calculated entry
            |> filter(fn: (r) => r["count"] == 1 and r["tag"] == "CALC")
            // Drop unnecessary columns
            |> drop(
                columns: [
                    "tag",
                    "tdiff",
                    "tag2",
                    "count",
                ],
            )

    return ret
}

// ===================================================================================================
// Start main program
// ===================================================================================================

cf = chargingFinished()

// Define a default array which is to be used if the chosen stop time is not after the end of a charging period
consNul =
    array.from(
        rows: [
            {
                _time: 1900-01-01T00:00:00Z,
                _measurement: "consumption",
                process: "charge",
                source: "CarCharger",
                vin: "000000000000",
                charged: 0.0,
                startcharging: 0,
            },
        ],
    )

// Determine energy consumption from charging periods 
// only if the end of a charging period has been sensed
cons = if chargingFinished() then consumptionFromCharging() else consNul

cons
    |> to(
        bucket: "Car_Consumption",
        timeColumn: "_time",
        measurementColumn: "_measurement",
        tagColumns: ["process", "source", "vin"],
        fieldFn: (r) => ({"energy": r.charged, "startcharging": r.startcharging}),
    )
