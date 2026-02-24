package handlers

import (
	"testing"

	"github.com/AndriyKalashnykov/flight-path/pkg/api"
)

// generateFlights creates a linear chain of n flights for benchmarking.
func generateFlights(n int) []api.Flight {
	flights := make([]api.Flight, n)
	for i := 0; i < n; i++ {
		flights[i] = api.Flight{
			Start: string(rune('A' + i)),
			End:   string(rune('A' + i + 1)),
		}
	}
	return flights
}

// Benchmarks for small dataset (10 flights)
func BenchmarkFindItinerary_10(b *testing.B) {
	flights := generateFlights(10)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FindItinerary(flights)
	}
}

// Benchmarks for medium dataset (50 flights)
func BenchmarkFindItinerary_50(b *testing.B) {
	flights := generateFlights(50)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FindItinerary(flights)
	}
}

// Benchmarks for large dataset (100 flights)
func BenchmarkFindItinerary_100(b *testing.B) {
	flights := generateFlights(100)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FindItinerary(flights)
	}
}

// Benchmarks for very large dataset (500 flights)
func BenchmarkFindItinerary_500(b *testing.B) {
	flights := generateFlights(500)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		FindItinerary(flights)
	}
}
