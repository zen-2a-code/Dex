//
//  Stats.swift
//  Dex
//
//  Created by Stoyan Hristov on 24.11.25.
//

import SwiftUI
import Charts

// Renders a simple bar chart of a Pokémon's stats using Swift Charts (horizontal bars).

// SwiftUI view that draws a chart from pokemon.stats (an array of Stat).
struct Stats: View {
    var pokemon: Pokemon
    
    var body: some View {
        // Chart iterates over the given data collection and builds marks per item.
        // Here, 'stat' is one element of pokemon.stats (with fields: name and value).
        Chart(pokemon.stats) {stat in
            // Horizontal bar: x = numeric value, y = category name.
            // .value("Label", value) takes a display label and a plottable value (e.g., Int, String).
            BarMark(x: .value("Value", stat.value),
                    y: .value("Status", stat.name)
            )
            // Show the numeric value at the end of each bar for quick reading.
            .annotation(position: .trailing) {
                Text("\(stat.value)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, -5)
            }
        }
        // Fixed height so the chart fits nicely in the detail screen.
        .frame(height: 200)
        // Color the bars by the Pokémon's primary type (comes from a Color asset).
        .foregroundStyle(pokemon.typeColor)
        // Set the X-axis range from 0 up to a bit above the biggest stat.
        // pokemon.highestStat is computed on the model using max(by:), and .value is that Stat's number.
        // +10 adds a little headroom so bars don't touch the edge.
        .chartXScale(domain: 0...pokemon.highestStat.value + 10)
    }
}

#Preview {
    Stats(pokemon: PersistenceController.previewPokemon)
}

// Explanation: Charts & BarMark
// Chart is a container that takes a data collection and for each element calls a closure to build one or more marks.
// BarMark is a mark type that draws horizontal or vertical bars.
// The .value() function takes a label (for axis or legend) and a plottable value such as Int, String, or Date.

// Explanation: how highestStat has .value property
// highestStat is computed from Pokemon.stats.max(by:), which returns the Stat with the largest value field.
// max(by:) returns an optional because the array could be empty.
// The closure for max(by:) uses shorthand $0/$1 to compare two Stat elements.
// The .value property is a numeric field inside the Stat struct representing that stat's amount.

// Best practices
// - Convert Int16 values from Core Data to Int or Double for charting to avoid type issues.
// - Avoid magic numbers like +10 by defining a named constant for chart axis padding.
// - If stats could be empty, use an optional-safe domain or provide a default range for the chart.
// - Localize axis labels ("Value", "Status") for internationalization.
// - Add accessibility labels and values to bars and annotations for better VoiceOver support.
// - Ensure color assets used for typeColor exist and consider fallback colors if missing.
