// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import {IPool} from "@yield-protocol/yieldspace-interfaces/IPool.sol";
import {IPoolOracle} from "./IPoolOracle.sol";

/**
 * @title PoolOracle
 * @author Bruno Bonanno
 * @dev This contract collects data from different YieldSpace pools to compute a TWAR using a SMA (https://www.investopedia.com/terms/s/sma.asp)
 * Adapted from https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol
 */
//solhint-disable not-rely-on-time
contract PoolOracle is IPoolOracle {
    event ObservationRecorded(address indexed pool, uint256 index, Observation observation);

    error NoObservationsForPool(address pool);
    error MissingHistoricalObservation(address pool);
    error InsufficientElapsedTime(address pool, uint256 elapsedTime);

    struct Observation {
        uint256 timestamp;
        uint256 ratioCumulative;
    }

    // the desired amount of time over which the moving average should be computed, e.g. 24 hours
    uint256 public immutable windowSize;
    // the number of observations stored for each pool, i.e. how many ratio observations are stored for the window.
    // as granularity increases from 1, more frequent updates are needed, but moving averages become more precise.
    // averages are computed over intervals with sizes in the range:
    //   [windowSize - (windowSize / granularity) * 2, windowSize]
    // e.g. if the window size is 24 hours, and the granularity is 24, the oracle will return the TWAR for
    //   the period:
    //   [now - [22 hours, 24 hours], now]
    uint256 public immutable granularity;
    // this is redundant with granularity and windowSize, but stored for gas savings & informational purposes.
    uint256 public immutable periodSize;
    // this is to avoid using values that are too close in time to the current observation
    uint256 public immutable minTimeElapsed;

    // mapping from pool address to a list of ratio observations of that pool
    mapping(address => Observation[]) public poolObservations;

    constructor(
        uint256 windowSize_,
        uint256 granularity_,
        uint256 minTimeElapsed_
    ) {
        require(granularity_ > 1, "GRANULARITY");
        require((periodSize = windowSize_ / granularity_) * granularity_ == windowSize_, "WINDOW_NOT_EVENLY_DIVISIBLE");
        windowSize = windowSize_;
        granularity = granularity_;
        minTimeElapsed = minTimeElapsed_;
    }

    // returns the index of the observation corresponding to the given timestamp
    function observationIndexOf(uint256 timestamp) public view returns (uint256 index) {
        uint256 epochPeriod = timestamp / periodSize;
        return epochPeriod % granularity;
    }

    // returns the observation from the oldest epoch (at the beginning of the window) relative to the current time
    function getOldestObservationInWindow(address pool) public view returns (Observation memory) {
        if (poolObservations[pool].length == 0) {
            revert NoObservationsForPool(pool);
        }

        unchecked {
            uint256 observationIndex = observationIndexOf(block.timestamp);
            uint256 length = poolObservations[pool].length;
            uint256 oldestObservationIndex;
            // can't possible overflow
            for (uint256 i; i < length; ++i) {
                // no overflow issue. if observationIndex + 1 overflows, result is still zero.
                oldestObservationIndex = (++observationIndex) % granularity;
                // If no data exists for this index, check the next one,
                // this should only happen during the first timeWindow for a given pool
                // If the elapsedTime is bigger than the timeWindow,
                // we also check the next one in case only this particular observation is stale
                if (block.timestamp - poolObservations[pool][oldestObservationIndex].timestamp < windowSize) {
                    return poolObservations[pool][oldestObservationIndex];
                }
            }

            revert MissingHistoricalObservation(pool);
        }
    }

    // @inheritdoc IPoolOracle
    function update(address pool) public override {
        // populate the array with empty observations (oldest call only)
        for (uint256 i = poolObservations[pool].length; i < granularity; i++) {
            poolObservations[pool].push();
        }

        // get the observation for the current period
        uint256 index = observationIndexOf(block.timestamp);
        Observation storage observation = poolObservations[pool][index];

        // we only want to commit updates once per period (i.e. windowSize / granularity)
        uint256 timeElapsed = block.timestamp - observation.timestamp;
        if (timeElapsed > periodSize) {
            observation.timestamp = block.timestamp;
            observation.ratioCumulative = _getCurrentCumulativeRatio(pool);
            emit ObservationRecorded(pool, index, observation);
        }
    }

    /// @inheritdoc IPoolOracle
    function peek(address pool) public view override returns (uint256 twar) {
        Observation memory oldestObservation = getOldestObservationInWindow(pool);

        uint256 timeElapsed = block.timestamp - oldestObservation.timestamp;
        if (timeElapsed > windowSize) {
            revert MissingHistoricalObservation(pool);
        }

        if (timeElapsed < minTimeElapsed) {
            revert InsufficientElapsedTime(pool, timeElapsed);
        }

        // cumulative ratio is in (ratio * seconds) units so for the average we simply get it after division by time elapsed
        return ((_getCurrentCumulativeRatio(pool) - oldestObservation.ratioCumulative) * 1e18) / (timeElapsed * 1e27);
    }

    /// @inheritdoc IPoolOracle
    function get(address pool) external override returns (uint256 twar) {
        update(pool);
        return peek(pool);
    }

    function _getCurrentCumulativeRatio(address pool) internal view returns (uint256 lastRatio) {
        lastRatio = IPool(pool).cumulativeBalancesRatio();
        (uint256 baseCached, uint256 fyTokenCached, uint256 blockTimestampLast) = IPool(pool).getCache();
        if (block.timestamp != blockTimestampLast) {
            lastRatio += ((fyTokenCached * 1e27 * (block.timestamp - blockTimestampLast)) / baseCached);
        }
    }
}
