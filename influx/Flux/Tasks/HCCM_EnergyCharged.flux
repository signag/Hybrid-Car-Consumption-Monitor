//=============================================================================================================
// This function calculates the energy charged through the charging device
// The energy will increase from zero after each charging cycle 
// When the charging cycle has finished it will fall to zero
//
// This is limited to a single car, for which the Vehicle Identification Number 
// and capacity must be spezified below
//=============================================================================================================
option task = {name: "HCCM_EnergyCharged", every: 5m}

// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"

tStart = -1d 
tStop = now()

chrg1 =
    from(bucket: "Car_Charging")
        // Get the energy captured for the Fritz! HA device used for charging
        |> range(start: tStart, stop: tStop)
        |> filter(fn: (r) => r["_measurement"] == "energy")
        |> filter(fn: (r) => r["sublocation"] == vin)
chrg2 =
    chrg1        
        // Keep only columns required for this analysis
        |> drop(
            columns: [
                "_measurement",
                "_start",
                "_stop",
            ],
        )
        // Sort with respect to _time to avoid issues with derivative
        |> sort(columns: ["_time"])
chrg3 =
    chrg2        
        // We are not interested in absolute overall values but only in relative increments
        |> increase()
        // Now, we differentiate the energy to get the power
        |> duplicate(column: "_value", as: "power")
        |> derivative(unit: 1h, columns: ["power"])
chrg4 =
    chrg3        
        // Measuring points indication zero power can be excluded
        |> filter(fn: (r) => r["power"] > 0)
        // Now, we define a step function (tag) on the power, setting all values below a threshold to zero.
        |> map(fn: (r) => ({r with tag: if r.power > 0.08 then 1 else 0}))
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
chrg5 =
    chrg4
        // Now, we keep only the charging periods (tag3 == 1)
        |> filter(fn: (r) => r["tag3"] == 1)
        // Now, we define tag4, which identifies all starting points of charging periods
        |> map(fn: (r) => ({r with tag4: if r.tag2 == 1 then 1 else 0}))
        // When accumulating tag4 in tag5, every charging period gets its individual value
        // because onty the starting points contribute whereas assl subsequent points of the same period don't
        |> duplicate(column: "tag4", as: "tag5")
        |> cumulativeSum(columns:["tag5"])
chrg6 =
    chrg5
        // This allows grouping with respect to charging periods
        |> group(columns: ["tag5"])
        // Cumulative sum of tag will count the measuring points of a period
        // Cumulative sum of tag4 (1 only for starting points) will indicate whether a sequence is complete
        // If a sequence does not include the starting point the sum will remain zero.
        |> cumulativeSum(columns: ["tag", "tag4"])
chrg7 =
    chrg6
        // Now, we keep only complete charging periods (tag4 == 1)
        |> filter(fn: (r) => r["tag4"] == 1)
        // We are not interested in absolute overall values but only in relative increments
        |> increase(
            columns: [
                "_value",
            ],
        )
chrg8 =
    chrg7
        // Now, we set the energy to 0 for the last point of each complete charging period
        |> map(fn: (r) => ({r with _value: if r.tag2 == -1 then 0.0 else r._value}))
        // Drop all unnecessary columns
        |> drop(
            columns: [
                "power",
                "tag",
                "tag2",
                "tag3",
                "tag4",
                "tag5",
            ],
        )
        // Add columns required for the bucket
        |> set(key: "_measurement", value: "charged")
chrg8
    |> to(
        bucket: "Car_Charging",
        timeColumn: "_time",
        measurementColumn: "_measurement",
        tagColumns: ["ain", "location", "sublocation", "state"],
        fieldFn: (r) => ({"value": r._value}),
    )
