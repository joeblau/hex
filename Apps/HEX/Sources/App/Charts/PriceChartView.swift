// PriceChartView.swift
// Copyright (c) 2022 Joe Blau

import BitqueryAPI
import Charts
import Foundation
import SwiftUI

struct PriceChartView: UIViewRepresentable {
    var chartScale: ChartScale
    var timeScale: TimeScale
    var chartType: ChartType
    var ohlcv: [OHLCVData]

    func makeUIView(context _: Context) -> CombinedChartView {
        let view = CombinedChartView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.drawBarShadowEnabled = false
        view.highlightFullBarEnabled = false
        view.drawBarShadowEnabled = false
        view.drawOrder = [CombinedChartView.DrawOrder.bar.rawValue,
                          CombinedChartView.DrawOrder.line.rawValue,
                          CombinedChartView.DrawOrder.candle.rawValue]

        view.gridBackgroundColor = .systemGroupedBackground
        view.legend.enabled = false

        view.xAxis.labelPosition = .bottom
        view.xAxis.gridColor = .systemGray5
        view.xAxis.axisLineColor = .systemGray5
        view.xAxis.labelCount = 6
        view.xAxis.labelTextColor = .secondaryLabel

        view.leftAxis.drawLabelsEnabled = false
        view.leftAxis.gridColor = .clear
        view.leftAxis.axisLineColor = .clear
        view.leftAxis.axisMinimum = 0.0

        view.rightAxis.gridColor = .systemGray5
        view.rightAxis.axisLineColor = .systemGray5
        view.rightAxis.valueFormatter = DefaultAxisValueFormatter(formatter: Formatter.currencyFormatter)
        view.rightAxis.labelTextColor = .secondaryLabel
        return view
    }

    func updateUIView(_ combinedView: CombinedChartView, context _: Context) {
        let combinedData = CombinedChartData()

        switch chartType {
        case .line:
            combinedData.lineData = generateData(ohlcv: ohlcv)
        case .candlestick:
            combinedData.candleData = generateData(ohlcv: ohlcv)
        }
        combinedData.barData = generateData(ohlcv: ohlcv)
        combinedView.data = combinedData

        if !ohlcv.isEmpty {
            combinedView.zoom(scaleX: 0, scaleY: 0, x: 0, y: 0)
            let pointsDisplayed = 60
            let xScale = Double(ohlcv.count / pointsDisplayed)
            combinedView.zoom(scaleX: xScale, scaleY: 1, x: 0, y: 0)
            combinedView.moveViewToX(Double(ohlcv.count))
        }
        combinedView.xAxis.valueFormatter = TimeAxisValueFormatter(chart: combinedView, timeScale: timeScale)
    }

    private func generateData(ohlcv: [OHLCVData]) -> CandleChartData {
        let candleEntries = ohlcv.enumerated().compactMap { index, entry -> CandleChartDataEntry in
            switch chartScale {
            case .liner:
                return CandleChartDataEntry(x: Double(index),
                                            shadowH: entry.high,
                                            shadowL: entry.low,
                                            open: entry.open,
                                            close: entry.close)
            case .log:
                return CandleChartDataEntry(x: Double(index),
                                            shadowH: log10(entry.high),
                                            shadowL: log10(entry.low),
                                            open: log10(entry.open),
                                            close: log10(entry.close))
            }
        }
        let set = CandleChartDataSet(entries: candleEntries, label: "Price")
        set.axisDependency = .right
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.neutralColor = .secondaryLabel
        set.decreasingColor = .systemRed
        set.increasingColor = .systemGreen
        set.shadowColorSameAsCandle = true
        set.showCandleBar = true
        set.decreasingFilled = true
        set.increasingFilled = true
        return CandleChartData(dataSet: set)
    }

    private func generateData(ohlcv: [OHLCVData]) -> LineChartData {
        let lineEntries = ohlcv.enumerated().compactMap { index, entry -> ChartDataEntry in
            switch chartScale {
            case .liner:
                return ChartDataEntry(x: Double(index),
                                      y: entry.close)
            case .log:
                return ChartDataEntry(x: Double(index), y:
                    log10(entry.close))
            }
        }

        let set = LineChartDataSet(entries: lineEntries, label: "Price")
        set.axisDependency = .right
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.setColor(.systemBlue)
        set.drawCirclesEnabled = false
        set.lineWidth = 2

        return LineChartData(dataSet: set)
    }

    private func generateData(ohlcv: [OHLCVData]) -> BarChartData {
        let volumeEntries = ohlcv.enumerated().compactMap { index, entry -> BarChartDataEntry in
            BarChartDataEntry(x: Double(index),
                              y: entry.volume)
        }

        let set = BarChartDataSet(entries: volumeEntries, label: "Volume")
        set.axisDependency = .left
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.setColor(.systemGray5)
        return BarChartData(dataSet: set)
    }
}
