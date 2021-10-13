// HEXSmartContractReducer.swift
// Copyright (c) 2021 Joe Blau

import BigInt
import ComposableArchitecture
import Dispatch
import HEXSmartContract

let hexReducer = Reducer<AppState, HEXSmartContractManager.Action, AppEnvironment> { state, action, environment in
    switch action {
    case let .stakeList(stakeList, address, chain):
        let accountDataKey = address.value + chain.description
        var totalStakeShares: BigUInt = 0
        var totalStakedHearts: BigUInt = 0
        let currentDay = state.currentDay

        let stakes = stakeList.sorted(by: {
            let firstStake = [BigUInt($0.lockedDay + $0.stakedDays), $0.stakeId]
            let secondStake = [BigUInt($1.lockedDay + $1.stakedDays), $1.stakeId]
            return firstStake.lexicographicallyPrecedes(secondStake)
        })
            .map { stake -> Stake in
                let stakeUnlockDay = BigUInt(stake.unlockedDay)
                let stakeLockedDay = BigUInt(stake.lockedDay)
                let servedDays = stakeLockedDay + BigUInt(stake.stakedDays)
                let gracePeriod = servedDays + k.GRACE_PERIOD

                let status: StakeStatus
                // Calculate Status
                if stake.unlockedDay > 0, stake.unlockedDay < stake.lockedDay + stake.stakedDays {
                    status = .emergencyEnd
                } else if stake.unlockedDay > 0, servedDays ..< currentDay ~= stakeUnlockDay {
                    status = .goodAccounting
                } else if stake.unlockedDay == 0, servedDays ..< gracePeriod ~= stakeUnlockDay {
                    status = .gracePeriod
                } else if stake.unlockedDay == 0, currentDay > gracePeriod {
                    status = .bleeding
                } else {
                    status = .active
                    totalStakeShares += stake.stakeShares
                    totalStakedHearts += stake.stakedHearts
                }

                var penaltyDays = (stake.stakedDays + 1) / 2
                if penaltyDays < k.EARLY_PENALTY_MIN_DAYS {
                    penaltyDays = UInt16(k.EARLY_PENALTY_MIN_DAYS)
                }
                
                let percentComplete = max(0, min(1, (Double(currentDay) - Double(stake.lockedDay)) / Double(stake.stakedDays)))
                return Stake(stakeId: stake.stakeId,
                             stakedHearts: stake.stakedHearts,
                             stakeShares: stake.stakeShares,
                             lockedDay: stake.lockedDay,
                             stakedDays: stake.stakedDays,
                             penaltyDays: penaltyDays,
                             unlockedDay: stake.unlockedDay,
                             isAutoStake: stake.isAutoStake,
                             percentComplete: percentComplete,
                             servedDays: UInt16(servedDays),
                             status: status,
                             startDate: k.HEX_START_DATE.addingTimeInterval(TimeInterval(Int(stakeLockedDay) * 86400)),
                             endDate: k.HEX_START_DATE.addingTimeInterval(TimeInterval(Int(servedDays) * 86400)),
                             interestHearts: 0,
                             interestSevenDayHearts: 0,
                             bigPayDayHearts: nil)
            }
        state.accountsData[id: accountDataKey]?.stakes = IdentifiedArray(uniqueElements: stakes)
        state.accountsData[id: accountDataKey]?.total.stakeShares = totalStakeShares
        state.accountsData[id: accountDataKey]?.total.stakedHearts = totalStakedHearts

        return environment.hexManager
            .getDailyDataRange(id: HexManagerId(),
                               address: address,
                               chain: chain,
                               begin: 0,
                               end: UInt16(state.currentDay))
            .fireAndForget()

    case let .dailyData(dailyDataEncoded, address, chain):
        let accountDataKey = address.value + chain.description
        var currentDay = state.currentDay

        let dailyData = dailyDataEncoded.map { dailyData -> DailyData in
            var dailyData = dailyData
            let payout = dailyData & k.HEARTS_MASK
            dailyData >>= k.HEARTS_UINT_SHIFT
            let shares = dailyData & k.HEARTS_MASK
            dailyData >>= k.HEARTS_UINT_SHIFT
            let sats = dailyData & k.SATS_MASK

            return DailyData(payout: payout, shares: shares, sats: sats)
        }

        state.accountsData[id: accountDataKey]?
            .stakes
            .forEach { stake in
                guard stake.lockedDay <= state.currentDay else { return }

                let startIndex = Int(stake.lockedDay)
                let endIndex = min(startIndex + Int(stake.stakedDays), Int(state.currentDay))
                let weekStartIndex = max(endIndex - 7, startIndex)

                // Total Interest
                let interest = stake.calculatePayout(globalInfo: state.globalInfo,
                                                   beginDay: startIndex,
                                                   endDay: endIndex,
                                                   dailyData: dailyData)
                state.accountsData[id: accountDataKey]?
                    .stakes[id: stake.id]?
                    .interestHearts = interest.payout
                state.accountsData[id: accountDataKey]?
                    .stakes[id: stake.id]?
                    .bigPayDayHearts = interest.bigPayDay
                
                // Seven Day Interest
                let sevenDayInterest = stake.calculatePayout(globalInfo: state.globalInfo,
                                                           beginDay: weekStartIndex,
                                                           endDay: endIndex,
                                                           dailyData: dailyData)
                state.accountsData[id: accountDataKey]?
                    .stakes[id: stake.id]?
                    .interestSevenDayHearts = sevenDayInterest.payout
            }

        let stakes = state.accountsData[id: accountDataKey]?.stakes
        
        let totalInterestHearts = stakes?.reduce(0, { $0 + $1.interestHearts }) ?? 0
        var totalInterestSevenDayHearts = stakes?.reduce(0, { $0 + $1.interestSevenDayHearts }) ?? 0
        let bigPayDayTotalHearts = stakes?.compactMap { $0.bigPayDayHearts }.reduce(0, { $0 + $1 })
        
        state.accountsData[id: accountDataKey]?.total.interestHearts = totalInterestHearts
        state.accountsData[id: accountDataKey]?.total.interestSevenDayHearts = (totalInterestSevenDayHearts / BigUInt(7))
        bigPayDayTotalHearts.map { state.accountsData[id: accountDataKey]?.total.bigPayDayHearts = $0 }

        return .none

    case let .currentDay(day):
        state.currentDay = day
        return .merge(
            state.accountsData.compactMap { accountData -> Effect<HEXSmartContractManager.Action, Never>? in
                environment.hexManager.getStakes(id: HexManagerId(),
                                                 address: accountData.account.address,
                                                 chain: accountData.account.chain).fireAndForget()
            }
        )

    case let .globalInfo(globalInfo):
        state.globalInfo = GlobalInfo(globalInfo: globalInfo)
        return .none
    }
}
