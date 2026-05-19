import SwiftUI
import Charts

nonisolated struct RateDataPoint: Identifiable, Sendable {
    let id = UUID()
    let day: String
    let rate: Double
    let series: String
}

struct RateChartView: View {
    let data: [(day: String, yours: Double, competitor: Double)]

    private var chartData: [RateDataPoint] {
        data.flatMap { item in
            [
                RateDataPoint(day: item.day, rate: item.yours, series: "Your Rate"),
                RateDataPoint(day: item.day, rate: item.competitor, series: "Competitor Avg")
            ]
        }
    }

    private var yAxisRange: ClosedRange<Double> {
        let allRates = chartData.map(\.rate).filter { $0 > 0 }
        guard let minRate = allRates.min(), let maxRate = allRates.max() else {
            return 0...200
        }
        let padding = max((maxRate - minRate) * 0.2, 10)
        return max(0, minRate - padding)...(maxRate + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rate Comparison")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("7 Days")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Chart(chartData) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Rate", point.rate)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Rate", point.rate)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .symbolSize(20)
            }
            .chartForegroundStyleScale([
                "Your Rate": RevOwlTheme.gold,
                "Competitor Avg": Color.secondary
            ])
            .chartYScale(domain: yAxisRange)
            .chartLegend(position: .bottom, spacing: 16)
            .chartLegend {
                HStack(spacing: 16) {
                    ForEach(["Your Rate", "Competitor Avg"], id: \.self) { series in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(series == "Your Rate" ? RevOwlTheme.gold : Color.secondary)
                                .frame(width: 6, height: 6)
                            Text(series)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let rate = value.as(Double.self) {
                            Text("$\(Int(rate))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                        .foregroundStyle(.primary.opacity(0.08))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .glassCardStyle()
    }
}
