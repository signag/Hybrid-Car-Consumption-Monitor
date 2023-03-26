//=========================================================================================
// This program calculates monthly statistics
// 
// This is limited to a single car, for which the Vehicle Identification Number must be spezified below
//=========================================================================================
import "timezone"
import "date"
import "array"
import "experimental/date/boundaries"

option task = {name: "HCCM_StatsCurMonth", every: 1h}

option location = timezone.location(name: "Europe/Berlin")

// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"

curMonth = boundaries.month(month_offset: -1)

//=========================================================================================
// check whether table has been dropped
// From https://medium.com/@marcodb.dev/flux-checking-for-empty-and-dropped-tables-f36134b3cd26
//=========================================================================================
isDropped = (tables) => {
    columnsArray = tables
        |> columns()
        |> findColumn(fn: (key) => true, column: "_value")
    return length(arr: columnsArray) == 0
}

//=========================================================================================
// check whether table has been dropped or is empty
// From https://medium.com/@marcodb.dev/flux-checking-for-empty-and-dropped-tables-f36134b3cd26
//=========================================================================================
isDroppedOrEmpty = (tables, column) => {
    cntArray = tables
        |> count(column: column)
        |> findColumn(fn: (key) => true, column: column)
    return if length(arr: cntArray) == 0 then true else
             if cntArray[0] == 0 then true else false
}

//=========================================================================================
// nullRec is used in cases where a result record cannot be found because source table is dropped or empty
//=========================================================================================
nullRec = {
            _time: 1900-01-01T00:00:00Z,
            _measurement: "null",
            label: "null",
            _value: 0,
            count: 0,
            tripMileage: 0,
            traveltime: 0,
            fuelConsumed: 0.0,
            electricEnergyConsumed: 0.0,
            electricEnergyCharged: 0.0,
            type: "null",
            tripCount: 0,
        }

//=========================================================================================
// Check whether trips exist for the intended range
//=========================================================================================
tripsTest = 
    from(bucket: "Car_Trips")
        |> range(start: curMonth.start, stop: curMonth.stop)
        |> filter(onEmpty: "drop", fn: (r) => r._measurement == "trip_shortTerm" and r.vin == vin)

tripsExist = not isDropped(tables: tripsTest)

//==================================================================================================
// Evaluate overall trip-related data
//==================================================================================================
tripsAll =
    from(bucket: "Car_Trips")
        // Get all short term trips within range
        |> range(start: curMonth.start, stop: curMonth.stop)
        |> filter(fn: (r) => r["_measurement"] == "trip_shortTerm")
        |> filter(fn: (r) => r["vin"] == vin)
        // Drop unnecessary columns
        |> drop(
            columns: [
                "_measurement",
                "_start",
                "_stop",
                "reportReason",
                "tripID",
            ],
        )
        // Pivot with respect to _time to get a table with rows based on _time and data as columns
        |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
        // Sorting the table with respect to _time is essential because Influx does not sort automatically
        |> sort(columns: ["_time"])
        //Rename "electricPowerConsumed" to "electricEnergyConsumed"
        |> duplicate(column: "electricPowerConsumed", as: "electricEnergyConsumed")
        |> drop(
            columns: [
                "electricPowerConsumed",
            ],
        )
        // The Car_Trips bucket includes all partial trips for which data are accumulated into the latest.
        // Whereas WeConnect finally keeps only the latest trip of a group, we also keep the partial trips
        // as long as they have been received from WeConnect before the entire trip has been "closed"
        // by a gap of at least 2 hours
        // All partial trips of a trip have the same "startMileage"
        // We only need to keep the last one
        |> group(columns: ["startMileage"])
        |> tail(n: 1)
        |> group()
        // Add column for counting the trips
        |> map(fn: (r) => ({r with count: 1}))

monthDataTotal =
    tripsAll
        // Accumulate relevant data rowwise
        |> cumulativeSum(
            columns: [
                "electricEnergyConsumed",
                "fuelConsumed",
                "traveltime",
                "tripMileage",
                "count",
            ],
        )
        // Keep the last row to get monthly sums
        |> last(column: "tripMileage")
        // Group to provide the key for later tableFind
        |> group(columns: ["vin"])


monthDataTotalRec = if tripsExist
    then
        monthDataTotal
            // Extract table from stream
            |> tableFind(fn: (key) => key.vin == vin)
            // Extract row from table
            |> getRecord(idx: 0)
    else
        // Set result to nullRecord in case no data were found
        nullRec

// Extract statistics data from sum record
time = curMonth.stop
measurement = "statistics"
tripsTotal = if tripsExist then monthDataTotalRec["count"] else 0
mileageTotal = if tripsExist then monthDataTotalRec["tripMileage"] else 0
traveltimeTotal = if tripsExist then monthDataTotalRec["traveltime"] else 0
fuelConsumed = if tripsExist then float(v: monthDataTotalRec["fuelConsumed"]) else 0.0
electricEnergyConsumedTotal = if tripsExist then float(v: monthDataTotalRec["electricEnergyConsumed"]) else 0.0

//==================================================================================================
// Evaluate trip-related data for purely electric trips
//==================================================================================================
tripsEl =
    tripsAll
        // Keep only trips for which no fuel was consumed
        // Sometimes short trips with mileage 0 are registered. These must be excluded
        |> filter(fn: (r) => r["fuelConsumed"] == 0 and r["tripMileage"] > 0)

monthDataEl =
    tripsEl
        // Accumulate relevant data rowwise
        |> cumulativeSum(
            columns: [
                "electricEnergyConsumed",
                "traveltime",
                "tripMileage",
                "count",
            ]
        )
        // Keep the last row to get monthly sums
        |> last(column: "tripMileage")
        // Group to provide the key for later tableFind
        |> group(columns: ["vin"])

// Check whether monthly data for purely electric trips exist
monthDataElExist = if not tripsExist then false else  not isDropped(tables: monthDataEl)

monthDataElRec = if monthDataElExist
    then
        monthDataEl
            // Extract table from stream
            |> tableFind(fn: (key) => key.vin == vin)
            // Extract row from table
            |> getRecord(idx: 0)
    else
        // Set result to nullRecord in case no data were found
        nullRec

// Extract statistics data from sum record
tripsElectric = if monthDataElExist then monthDataElRec["count"] else 0
mileageElectric = if monthDataElExist then monthDataElRec["tripMileage"] else 0
traveltimeElectric = if monthDataElExist then monthDataElRec["traveltime"] else 0
electricEnergyConsumedElectric = if monthDataElExist  then float(v: monthDataElRec["electricEnergyConsumed"]) else 0.0

//==================================================================================================
// Evaluate statistics data for all charging cycles
//==================================================================================================
chrgMonth =
    from(bucket: "Car_Consumption")
        // Get all Car_Consumption entries within the range, representing charging events
        // (_field == "energy" AND source == "home")
        |> range(start: curMonth.start, stop: curMonth.stop)
        |> filter(fn: (r) => r["_measurement"] == "consumption")
        |> filter(fn: (r) => r["vin"] == vin)
        |> filter(fn: (r) => r["_field"] == "energy")
        |> filter(fn: (r) => r["process"] == "charge")
        // Drop unnecessary columns
        |> drop(
            columns: [
                "_measurement",
                "_start",
                "_stop",
                "process",
                "source",
                "vin",
            ],
        )
        // Add column for counting the charging events
        |> map(fn: (r) => ({r with count: 1}))

chrgTotal =
    chrgMonth
        // Sum up charged energy (_value) and number of charging events
        |> cumulativeSum(columns: ["_value", "count"])
        // Keep the last row to get monthly sums
        |> last(column: "count")
        // Group to provide the key for later tableFind
        |> group(columns: ["_field"])

// Check whether charging events exist within the given range
chrgTotalExist = if not tripsExist then false else  not isDropped(tables: chrgTotal)

chrgTotalRec = if chrgTotalExist
    then
        chrgTotal
            // Extract table from stream
            |> tableFind(fn: (key) => key._field == "energy")
            // Extract row from table
            |> getRecord(idx: 0)
    else
        // Set result to nullRecord in case no data were found
        nullRec

// Extract statistics data from sum record
chargeCyclesTotal = if chrgTotalExist then chrgTotalRec["count"] else 0
electricEnergyChargedTotal = if chrgTotalExist then float(v: chrgTotalRec["_value"]) else 0.0

//==================================================================================================
// Evaluate data for charging cycles related to purely electric trips
// This requires a separate step because a single charging event may be related to multiple trips
// where one or more may have required fuel.
// So, we need to restrict trips and charging events to those situations where all trips previous
// to a charging event were purely electric
// This will be the basis for calculating statistical consumption data for purely electric trips
//
// The basis for this evaluation will be a union of a table of trips data with a table of charging events
// From the resulting table, only those groups of trips and related charging event will be kept
// for which no fuel has been consumed
//==================================================================================================
tripsAllEl =
    // first create a table of trips, starting from all trips
    tripsAll
        // Drop unnecessary columns
        |> drop(
            columns: [
                "startMileage",
                "count",
            ],
        )
        // Add column related to charging, initielized with zero
        |> map(fn: (r) => ({r with electricEnergyCharged: 0.0}))
        // Add a column indicating the trip (process=0)
        |> map(fn: (r) => ({r with process: 0}))

chrgElMonth =
    // Next create a table of charging events, starting form all charging events
    chrgMonth
        // drop unnecessary columns
        |> drop(
            columns: [
                "_field",
                "count",
            ],
        )
        //Rename the _value column to "electricEnergyCharged"
        |> duplicate(column: "_value", as: "electricEnergyCharged")
        |> drop(
            columns: [
                "_value",
            ],
        )
        // Add columns found in the tripsAllEl table initialized with zero
        |> map(fn: (r) => ({r with electricEnergyConsumed: 0.0}))
        |> map(fn: (r) => ({r with fuelConsumed: 0.0}))
        |> map(fn: (r) => ({r with traveltime: 0}))
        |> map(fn: (r) => ({r with tripMileage: 0}))
        // Add a column indicating the charging event (process=1)
        |> map(fn: (r) => ({r with process: 1}))

tripsAndCharging =
    // Union streams with trips and charging tables
    // Since both tables have the same set of columns, the resulting stream will be
    // grouped into a single table
    // The resulting table is not sorted with respect to _time
    union(tables: [chrgElMonth, tripsAllEl])

tripsAndChargingEl =
    tripsAndCharging
        // Sort with respect to _time to get the correct sequence of trips and charging events
        |> sort(columns: ["_time"])
        // The tag column will contain the cumuative sum of the process column
        // Since trips have process=0 and charging have process=1, as a result
        // the tag values for the charging events are larger by 1 compared to all related trips
        |> duplicate(column: "process", as: "tag")
        |> cumulativeSum(columns:["tag"])
        // Now, we create column tag3 to be used 
        // after grouping to check whether charging has been completed after a trip
        |> duplicate(column: "process", as: "tag3")
        // Now, in new column tag2, increment tag by 1 for all trips so that afterwards charging events
        // and related trips have the same tag2 values
        |> map(fn: (r) => ({r with tag2: if r.process == 0 then r.tag + 1 else r.tag}))
        // We add a new column tripCount, which is used to count the number of trips
        // associated with charging events for purely electric trips
        |> map(fn: (r) => ({r with tripCount: if r.process == 0 then 1 else 0}))
        // Now, we group the stream with respect to tag2 so that related trips and charging event
        // are in the same table
        |> group(columns: ["tag2"])
        // Now, we sum tag3 within the different tables to see whether a set of trips 
        // has been followed by a complete charging process
        |> cumulativeSum(columns:["tag3"])
        // Now, we sum up the relevant startistics data for all trips associated with the same charging event
        |> cumulativeSum(columns: ["electricEnergyCharged", "electricEnergyConsumed", "fuelConsumed", "traveltime", "tripMileage", "tripCount"])
        // Only the last row in each table is kept which carries the sums for all trips preceding a charging event
        |> tail(n: 1)
        // Now, the stream can be ungrouped to have the results in a single table,
        // one row for each charging event  associated with purely electric trips
        |> group()
        // Now, we keep only entries where no fuel was consumed in all trips preceding a charging event
        // By that, we are sure that the charged energy was used for purely electric trips
        |> filter(fn: (r) => r["fuelConsumed"] == 0.0)
        // Now, we filter trips after which charging is not yet completed
        |> filter(fn: (r) => r["tag3"] > 0)
        // We add a column for counting the charging events for purely electric trips
        |> map(fn: (r) => ({r with count: 1}))
        // Unnecessary columns are dropped
        |> drop(
            columns: [
                "fuelConsumed",
                "process",
                "tag",
                "tag2",
                "tag3",
            ],
        )

tripsAndChargingElTotal =
    tripsAndChargingEl
        // Now, we sum up statistical data for the entire range
        |> cumulativeSum(columns: ["electricEnergyCharged", "electricEnergyConsumed", "traveltime", "tripMileage", "tripCount", "count"])
        // ... and keep unly the last record containg the sums
        |> last(column: "count")
        // We add a column to be used as grouping key for later tableFind
        |> map(fn: (r) => ({r with type: "CCEl"}))
        |> group(columns: ["type"])

// Check whether the result table has any entries
tripsAndChargingElTotalExist = not isDropped(tables: tripsAndChargingElTotal)

tripsAndChargingElTotalRec = if tripsAndChargingElTotalExist
    then
        tripsAndChargingElTotal
            // Extract table from stream
            |> tableFind(fn: (key) => key.type == "CCEl")
            // Extract row from table
            |> getRecord(idx: 0)
    else
        // Set result to nullRecord in case no data were found
        nullRec

// Extract statistics data from sum record
tripsElectricChargeCycles = if tripsAndChargingElTotalExist then tripsAndChargingElTotalRec["tripCount"] else 0
chargeCyclesElectric = if tripsAndChargingElTotalExist then tripsAndChargingElTotalRec["count"] else 0
electricEnergyChargedElectric = if tripsAndChargingElTotalExist then tripsAndChargingElTotalRec["electricEnergyCharged"] else 0.0
electricEnergyConsumedElectricChargeCycles = if tripsAndChargingElTotalExist then tripsAndChargingElTotalRec["electricEnergyConsumed"] else 0.0
mileageElectricChargeCycles = if tripsAndChargingElTotalExist then tripsAndChargingElTotalRec["tripMileage"] else 0

// Construct table with rows for the statistical data at the evaluation time
// Evaluation time is the end of the evaluation period, e.g. end of a month
tab =
    array.from(
        rows: [
            {
                _time: time,
                _measurement: measurement,
                tripsTotal: tripsTotal,
                tripsElectric: tripsElectric,
                tripsElectricChargeCycles: tripsElectricChargeCycles,
                mileageTotal: mileageTotal,
                mileageElectric: mileageElectric,
                mileageElectricChargeCycles: mileageElectricChargeCycles,
                traveltimeTotal: traveltimeTotal,
                traveltimeElectric: traveltimeElectric,
                fuelConsumed: fuelConsumed,
                electricEnergyConsumedTotal: electricEnergyConsumedTotal,
                electricEnergyConsumedElectric: electricEnergyConsumedElectric,
                electricEnergyConsumedElectricChargeCycles: electricEnergyConsumedElectricChargeCycles,
                chargeCyclesTotal: chargeCyclesTotal,
                chargeCyclesElectric: chargeCyclesElectric,
                electricEnergyChargedTotal: electricEnergyChargedTotal,
                electricEnergyChargedElectric: electricEnergyChargedElectric,
                vin: vin,
            },
        ],
    )

// Write data to InfluxDB bucket 
tab
    |> to(bucket: "Car_Monthly",
            timeColumn: "_time",
            measurementColumn: "_measurement",
            tagColumns: ["vin"],
            fieldFn: (r) => 
            ({
                "tripsTotal": r.tripsTotal,
                "tripsElectric": r.tripsElectric,
                "tripsElectricChargeCycles": r.tripsElectricChargeCycles,
                "mileageTotal": r.mileageTotal,
                "mileageElectric": r.mileageElectric,
                "mileageElectricChargeCycles": r.mileageElectricChargeCycles,
                "traveltimeTotal": r.traveltimeTotal,
                "traveltimeElectric": r.traveltimeElectric,
                "fuelConsumed": r.fuelConsumed,
                "electricEnergyConsumedTotal": r.electricEnergyConsumedTotal,
                "electricEnergyConsumedElectric": r.electricEnergyConsumedElectric,
                "electricEnergyConsumedElectricChargeCycles": r.electricEnergyConsumedElectricChargeCycles,
                "chargeCyclesTotal": chargeCyclesTotal,
                "chargeCyclesElectric": chargeCyclesElectric,
                "electricEnergyChargedTotal": electricEnergyChargedTotal,
                "electricEnergyChargedElectric": electricEnergyChargedElectric
            }),
        )