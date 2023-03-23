//=============================================================================================================
// This function calculates the energy stored in the car HV Battery
// Since WEConnect only provides stateOfCharge as a percentage, 
// the actual energy needs to be calculated based on the specific battery capacity
//
// This is limited to a single car, for which the Vehicle Identification Number 
// and capacity must be spezified below
//=============================================================================================================
option task = {name: "HCCM_EnergyBat", every: 1h, offset: 1m}

// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"

// !!!!!!!!!!!! XXXX ! Specify battery capacity in kWh here !!!!!!!!!!!!!!!!!!!!!!!!!!!
HVBatCapacity = 10.0

from(bucket: "Car_Status")
    // Get the status entries of the last two hours
    |> range(start: -2h)
    |> filter(fn: (r) => r["_measurement"] == "carStatus")
    |> filter(fn: (r) => r["vin"] == vin)
    // Filter only stateOfCharge Data Points
    |> filter(fn: (r) => r["_field"] == "stateOfCharge")
    // Calculate battery energy
    |> map(
        fn: (r) =>
            ({
                _measurement: "carStatus",
                _time: r._time,
                vin: r.vin,
                _field: "batteryEnergy",
                _value: HVBatCapacity * float(v: r._value) / 100.0,
            }),
    )
    |> to(bucket: "Car_Status")