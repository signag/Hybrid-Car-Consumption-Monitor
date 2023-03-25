//=========================================================================================
// This program stores car-related prices on a monthly base
//=========================================================================================
import "date"
import "array"
import "experimental/date/boundaries"
import "timezone"

option location = timezone.location(name: "Europe/Berlin")

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! XX !!!! Specify month offset here (0 for current month, -1 for last month, ...)
theMonth = boundaries.month(month_offset:  0)

// !!!!!!!!!!!!!!! XXX !!!! Specify electricity price here in €/kWh
electricityPrice = 0.3

// !!!!!!!! XXXX !!!! Specify fuel price here (in €/l)
fuelPrice = 1.75


// !!! XXXXXXXXXXXXXXXXX ! Specify Vecicle Identification Number here !!!!!!!!!!!!!!!!!
vin = "XXXXXXXXXXXXXXXXX"

time = theMonth.stop
measurement = "statistics"

tab = array.from(rows: [
        {
            _time: time, 
            _measurement: measurement,
            electricityPrice: electricityPrice,
            fuelPrice: fuelPrice,
            vin: vin
        }
    ])

tab
    |> to(bucket: "Car_Monthly",
            timeColumn: "_time",
            measurementColumn: "_measurement",
            tagColumns: ["vin"],
            fieldFn: (r) => 
            ({
                "electricityPrice": r.electricityPrice,
                "fuelPrice": r.fuelPrice,
            }),
        )
