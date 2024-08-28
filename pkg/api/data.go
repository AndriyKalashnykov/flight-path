package api

type Flight struct {
	Start string
	End   string
}

// TestFlights start: BGY; end: AKL
var TestFlights = []Flight{
	{
		Start: "BCN",
		End:   "PSC",
	},
	{
		Start: "JFK",
		End:   "AAL",
	},
	{
		Start: "FCO",
		End:   "BCN",
	},
	{
		Start: "GSO",
		End:   "IND",
	},
	{
		Start: "SFO",
		End:   "ATL",
	},
	{
		Start: "AAL",
		End:   "HEL",
	},
	{
		Start: "PSC",
		End:   "BLQ",
	},
	{
		Start: "IND",
		End:   "EWR",
	},
	{
		Start: "BGY",
		End:   "RAR",
	},
	{
		Start: "BJZ",
		End:   "AKL",
	},
	{
		Start: "AUH",
		End:   "FCO",
	},
	{
		Start: "HEL",
		End:   "CAK",
	},
	{
		Start: "RAR",
		End:   "AUH",
	},
	{
		Start: "CAK",
		End:   "BJZ",
	},
	{
		Start: "ATL",
		End:   "GSO",
	},
	{
		Start: "CHI",
		End:   "JFK",
	},
	{
		Start: "BLQ",
		End:   "MAD",
	},
	{
		Start: "EWR",
		End:   "CHI",
	},
	{
		Start: "MAD",
		End:   "SFO",
	},
}
