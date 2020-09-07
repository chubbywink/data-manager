// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * Yield Math Smart Contract Library.
 */
pragma solidity ^0.6.0;

import "../pool/Math64x64.sol";

/**
 * Ethereum smart contract library implementing Yield Math model.
 */
library YieldMath48 {
  /**
   * Calculate the amount of yDAI a user would get for given amount of Dai.
   *
   * @param daiReserves Dai reserves amount
   * @param yDAIReserves yDAI reserves amount
   * @param daiAmount Dai amount to be traded
   * @param timeTillMaturity time till maturity in seconds
   * @param k time till maturity coefficient, multiplied by 2^64
   * @param g fee coefficient, multiplied by 2^64
   * @return the amount of yDAI a user would get for given amount of Dai
   */
  function yDaiOutForDaiIn (
    uint128 daiReserves, uint128 yDAIReserves, uint128 daiAmount,
    uint128 timeTillMaturity, int128 k, int128 g)
  internal pure returns (uint128) {
    // t = k * timeTillMaturity
    int128 t = Math64x64.mul (k, Math64x64.fromUInt (timeTillMaturity));

    // a = (1 - gt)
    int128 a = Math64x64.sub (0x10000000000000000, Math64x64.mul (g, t));
    require (a > 0, "YieldMath: Too far from maturity");

    // xdx = daiReserves + daiAmount
    uint256 xdx = uint256 (daiReserves) + uint256 (daiAmount);
    require (xdx < 0x100000000000000000000000000000000, "YieldMath: Too much Dai in");

    uint256 sum =
      uint256 (pow (daiReserves, uint128 (a), 0x10000000000000000)) +
      uint256 (pow (yDAIReserves, uint128 (a), 0x10000000000000000)) -
      uint256 (pow (uint128(xdx), uint128 (a), 0x10000000000000000));
    require (sum < 0x100000000000000000000000000000000, "YieldMath: Insufficient yDAI reserves");

    uint256 result = yDAIReserves - pow (uint128 (sum), 0x10000000000000000, uint128 (a));
    require (result < 0x100000000000000000000000000000000, "YieldMath: Rounding induced error");
    result > 1e12 ? result = result - 1e12 : result = 0; // Substract error guard, flooring the result at zero

    return uint128 (result);
  }

  /**
   * Calculate the amount of Dai a user would get for certain amount of yDAI.
   *
   * @param daiReserves Dai reserves amount
   * @param yDAIReserves yDAI reserves amount
   * @param yDAIAmount yDAI amount to be traded
   * @param timeTillMaturity time till maturity in seconds
   * @param k time till maturity coefficient, multiplied by 2^64
   * @param g fee coefficient, multiplied by 2^64
   * @return the amount of Dai a user would get for given amount of yDAI
   */
  function daiOutForYDaiIn (
    uint128 daiReserves, uint128 yDAIReserves, uint128 yDAIAmount,
    uint128 timeTillMaturity, int128 k, int128 g)
  internal pure returns (uint128) {
    // t = k * timeTillMaturity
    int128 t = Math64x64.mul (k, Math64x64.fromUInt (timeTillMaturity));

    // a = (1 - t/g)
    int128 a = Math64x64.sub (0x10000000000000000, Math64x64.div (t, g));
    require (a > 0, "YieldMath: Too far from maturity");

    // ydy = yDAIReserves + yDAIAmount;
    uint256 ydy = uint256 (yDAIReserves) + uint256 (yDAIAmount);
    require (ydy < 0x100000000000000000000000000000000, "YieldMath: Too much yDai in");

    uint256 sum =
      uint256 (pow (uint128 (daiReserves), uint128 (a), 0x10000000000000000)) -
      uint256 (pow (uint128 (ydy), uint128 (a), 0x10000000000000000)) +
      uint256 (pow (yDAIReserves, uint128 (a), 0x10000000000000000));
    require (sum < 0x100000000000000000000000000000000, "YieldMath: Insufficient Dai reserves");

    uint256 result =
      daiReserves -
      pow (uint128 (sum), 0x10000000000000000, uint128 (a));
    require (result < 0x100000000000000000000000000000000, "YieldMath: Rounding induced error");
    result > 1e12 ? result = result - 1e12 : result = 0; // Substract error guard, flooring the result at zero

    return uint128 (result);
  }

  /**
   * Calculate the amount of yDAI a user could sell for given amount of Dai.
   *
   * @param daiReserves Dai reserves amount
   * @param yDAIReserves yDAI reserves amount
   * @param daiAmount Dai amount to be traded
   * @param timeTillMaturity time till maturity in seconds
   * @param k time till maturity coefficient, multiplied by 2^64
   * @param g fee coefficient, multiplied by 2^64
   * @return the amount of yDAI a user could sell for given amount of Dai
   */
  function yDaiInForDaiOut (
    uint128 daiReserves, uint128 yDAIReserves, uint128 daiAmount,
    uint128 timeTillMaturity, int128 k, int128 g)
  internal pure returns (uint128) {
    // t = k * timeTillMaturity
    int128 t = Math64x64.mul (k, Math64x64.fromUInt (timeTillMaturity));

    // a = (1 - t/g)
    int128 a = Math64x64.sub (0x10000000000000000, Math64x64.div (t, g));
    require (a > 0, "YieldMath: Too far from maturity");

    // xdx = daiReserves - daiAmount
    uint256 xdx = uint256 (daiReserves) - uint256 (daiAmount);
    require (xdx < 0x100000000000000000000000000000000, "YieldMath: Too much Dai out");

    uint256 sum =
      uint256 (pow (uint128 (daiReserves), uint128 (a), 0x10000000000000000)) +
      uint256 (pow (yDAIReserves, uint128 (a), 0x10000000000000000)) -
      uint256 (pow (uint128 (xdx), uint128 (a), 0x10000000000000000));
    require (sum < 0x100000000000000000000000000000000, "YieldMath: Resulting yDai reserves too high");

    uint256 result = pow (uint128 (sum), 0x10000000000000000, uint128 (a)) - yDAIReserves;
    require (result < 0x100000000000000000000000000000000, "YieldMath: Rounding induced error");
    result < type(uint256).max - 1e12 ? result = result + 1e12 : result = type(uint256).max; // Add error guard, ceiling the result at max

    return uint128 (result);
  }

  /**
   * Calculate the amount of Dai a user would have to pay for certain amount of
   * yDAI.
   *
   * @param daiReserves Dai reserves amount
   * @param yDAIReserves yDAI reserves amount
   * @param yDAIAmount yDAI amount to be traded
   * @param timeTillMaturity time till maturity in seconds
   * @param k time till maturity coefficient, multiplied by 2^64
   * @param g fee coefficient, multiplied by 2^64
   * @return the amount of Dai a user would have to pay for given amount of
   *         yDAI
   */
  function daiInForYDaiOut (
    uint128 daiReserves, uint128 yDAIReserves, uint128 yDAIAmount,
    uint128 timeTillMaturity, int128 k, int128 g)
  internal pure returns (uint128) {
    // a = (1 - g * k * timeTillMaturity)
    int128 a = Math64x64.sub (0x10000000000000000, Math64x64.mul (g, Math64x64.mul (k, Math64x64.fromUInt (timeTillMaturity))));
    require (a > 0, "YieldMath: Too far from maturity");

    // ydy = yDAIReserves - yDAIAmount;
    uint256 ydy = uint256 (yDAIReserves) - uint256 (yDAIAmount);
    require (ydy < 0x100000000000000000000000000000000, "YieldMath: Too much yDai out");

    uint256 sum =
      uint256 (pow (daiReserves, uint128 (a), 0x10000000000000000)) +
      uint256 (pow (yDAIReserves, uint128 (a), 0x10000000000000000)) -
      uint256 (pow (uint128 (ydy), uint128 (a), 0x10000000000000000));
    require (sum < 0x100000000000000000000000000000000, "YieldMath: Resulting Dai reserves too high");

    uint256 result =
      pow (uint128 (sum), 0x10000000000000000, uint128 (a)) -
      daiReserves;
    require (result < 0x100000000000000000000000000000000, "YieldMath: Rounding induced error");
    result < type(uint256).max - 1e12 ? result = result + 1e12 : result = type(uint256).max; // Add error guard, ceiling the result at max

    return uint128 (result);
  }

  /**
   * Raise given number x into power specified as a simple fraction y/z and then
   * multiply the result by the normalization factor 2^(128 * (1 - y/z)).
   * Revert if z is zero, or if both x and y are zeros.
   *
   * @param x number to raise into given power y/z
   * @param y numerator of the power to raise x into
   * @param z denominator of the power to raise x into
   * @return x raised into power y/z and then multiplied by 2^(128 * (1 - y/z))
   */
  function pow (uint128 x, uint128 y, uint128 z)
  internal pure returns (uint128) {
    require (z != 0);

    if (x == 0) {
      require (y != 0);
      return 0;
    } else {
      uint256 l =
        uint256 (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF - log_2 (x)) * y / z;
      if (l > 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) return 0;
      else return pow_2 (uint128 (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF - l));
    }
  }

  /**
   * Calculate base 2 logarithm of an unsigned 128-bit integer number.  Revert
   * in case x is zero.
   *
   * @param x number to calculate base 2 logarithm of
   * @return base 2 logarithm of x, multiplied by 2^121
   */
  function log_2 (uint128 x)
  internal pure returns (uint128) {
    require (x != 0);

    uint b = x;

    uint l = 0xFE000000000000000000000000000000;

    if (b < 0x10000000000000000) {l -= 0x80000000000000000000000000000000; b <<= 64;}
    if (b < 0x1000000000000000000000000) {l -= 0x40000000000000000000000000000000; b <<= 32;}
    if (b < 0x10000000000000000000000000000) {l -= 0x20000000000000000000000000000000; b <<= 16;}
    if (b < 0x1000000000000000000000000000000) {l -= 0x10000000000000000000000000000000; b <<= 8;}
    if (b < 0x10000000000000000000000000000000) {l -= 0x8000000000000000000000000000000; b <<= 4;}
    if (b < 0x40000000000000000000000000000000) {l -= 0x4000000000000000000000000000000; b <<= 2;}
    if (b < 0x80000000000000000000000000000000) {l -= 0x2000000000000000000000000000000; b <<= 1;}

    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000;}
    /* Precision reduced to 64 bits
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2;}
    b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) l |= 0x1;
    */

    return uint128 (l);
  }

  /**
   * Calculate 2 raised into given power.
   *
   * @param x power to raise 2 into, multiplied by 2^121
   * @return 2 raised into given power
   */
  function pow_2 (uint128 x)
  internal pure returns (uint128) {
    uint r = 0x80000000000000000000000000000000;
    if (x & 0x1000000000000000000000000000000 > 0) r = r * 0xb504f333f9de6484597d89b3754abe9f >> 127;
    if (x & 0x800000000000000000000000000000 > 0) r = r * 0x9837f0518db8a96f46ad23182e42f6f6 >> 127;
    if (x & 0x400000000000000000000000000000 > 0) r = r * 0x8b95c1e3ea8bd6e6fbe4628758a53c90 >> 127;
    if (x & 0x200000000000000000000000000000 > 0) r = r * 0x85aac367cc487b14c5c95b8c2154c1b2 >> 127;
    if (x & 0x100000000000000000000000000000 > 0) r = r * 0x82cd8698ac2ba1d73e2a475b46520bff >> 127;
    if (x & 0x80000000000000000000000000000 > 0) r = r * 0x8164d1f3bc0307737be56527bd14def4 >> 127;
    if (x & 0x40000000000000000000000000000 > 0) r = r * 0x80b1ed4fd999ab6c25335719b6e6fd20 >> 127;
    if (x & 0x20000000000000000000000000000 > 0) r = r * 0x8058d7d2d5e5f6b094d589f608ee4aa2 >> 127;
    if (x & 0x10000000000000000000000000000 > 0) r = r * 0x802c6436d0e04f50ff8ce94a6797b3ce >> 127;
    if (x & 0x8000000000000000000000000000 > 0) r = r * 0x8016302f174676283690dfe44d11d008 >> 127;
    if (x & 0x4000000000000000000000000000 > 0) r = r * 0x800b179c82028fd0945e54e2ae18f2f0 >> 127;
    if (x & 0x2000000000000000000000000000 > 0) r = r * 0x80058baf7fee3b5d1c718b38e549cb93 >> 127;
    if (x & 0x1000000000000000000000000000 > 0) r = r * 0x8002c5d00fdcfcb6b6566a58c048be1f >> 127;
    if (x & 0x800000000000000000000000000 > 0) r = r * 0x800162e61bed4a48e84c2e1a463473d9 >> 127;
    if (x & 0x400000000000000000000000000 > 0) r = r * 0x8000b17292f702a3aa22beacca949013 >> 127;
    if (x & 0x200000000000000000000000000 > 0) r = r * 0x800058b92abbae02030c5fa5256f41fe >> 127;
    if (x & 0x100000000000000000000000000 > 0) r = r * 0x80002c5c8dade4d71776c0f4dbea67d6 >> 127;
    if (x & 0x80000000000000000000000000 > 0) r = r * 0x8000162e44eaf636526be456600bdbe4 >> 127;
    if (x & 0x40000000000000000000000000 > 0) r = r * 0x80000b1721fa7c188307016c1cd4e8b6 >> 127;
    if (x & 0x20000000000000000000000000 > 0) r = r * 0x8000058b90de7e4cecfc487503488bb1 >> 127;
    if (x & 0x10000000000000000000000000 > 0) r = r * 0x800002c5c8678f36cbfce50a6de60b14 >> 127;
    if (x & 0x8000000000000000000000000 > 0) r = r * 0x80000162e431db9f80b2347b5d62e516 >> 127;
    if (x & 0x4000000000000000000000000 > 0) r = r * 0x800000b1721872d0c7b08cf1e0114152 >> 127;
    if (x & 0x2000000000000000000000000 > 0) r = r * 0x80000058b90c1aa8a5c3736cb77e8dff >> 127;
    if (x & 0x1000000000000000000000000 > 0) r = r * 0x8000002c5c8605a4635f2efc2362d978 >> 127;
    if (x & 0x800000000000000000000000 > 0) r = r * 0x800000162e4300e635cf4a109e3939bd >> 127;
    if (x & 0x400000000000000000000000 > 0) r = r * 0x8000000b17217ff81bef9c551590cf83 >> 127;
    if (x & 0x200000000000000000000000 > 0) r = r * 0x800000058b90bfdd4e39cd52c0cfa27c >> 127;
    if (x & 0x100000000000000000000000 > 0) r = r * 0x80000002c5c85fe6f72d669e0e76e411 >> 127;
    if (x & 0x80000000000000000000000 > 0) r = r * 0x8000000162e42ff18f9ad35186d0df28 >> 127;
    if (x & 0x40000000000000000000000 > 0) r = r * 0x80000000b17217f84cce71aa0dcfffe7 >> 127;
    if (x & 0x20000000000000000000000 > 0) r = r * 0x8000000058b90bfc07a77ad56ed22aaa >> 127;
    if (x & 0x10000000000000000000000 > 0) r = r * 0x800000002c5c85fdfc23cdead40da8d6 >> 127;
    if (x & 0x8000000000000000000000 > 0) r = r * 0x80000000162e42fefc25eb1571853a66 >> 127;
    if (x & 0x4000000000000000000000 > 0) r = r * 0x800000000b17217f7d97f692baacded5 >> 127;
    if (x & 0x2000000000000000000000 > 0) r = r * 0x80000000058b90bfbead3b8b5dd254d7 >> 127;
    if (x & 0x1000000000000000000000 > 0) r = r * 0x8000000002c5c85fdf4eedd62f084e67 >> 127;
    if (x & 0x800000000000000000000 > 0) r = r * 0x800000000162e42fefa58aef378bf586 >> 127;
    if (x & 0x400000000000000000000 > 0) r = r * 0x8000000000b17217f7d24a78a3c7ef02 >> 127;
    if (x & 0x200000000000000000000 > 0) r = r * 0x800000000058b90bfbe9067c93e474a6 >> 127;
    if (x & 0x100000000000000000000 > 0) r = r * 0x80000000002c5c85fdf47b8e5a72599f >> 127;
    /* Precision reduced to 48 bits
    if (x & 0x80000000000000000000 > 0) r = r * 0x8000000000162e42fefa3bdb315934a2 >> 127;
    if (x & 0x40000000000000000000 > 0) r = r * 0x80000000000b17217f7d1d7299b49c46 >> 127;
    if (x & 0x20000000000000000000 > 0) r = r * 0x8000000000058b90bfbe8e9a8d1c4ea0 >> 127;
    if (x & 0x10000000000000000000 > 0) r = r * 0x800000000002c5c85fdf4745969ea76f >> 127;
    if (x & 0x8000000000000000000 > 0) r = r * 0x80000000000162e42fefa3a0df5373bf >> 127;
    if (x & 0x4000000000000000000 > 0) r = r * 0x800000000000b17217f7d1cff4aac1e1 >> 127;
    if (x & 0x2000000000000000000 > 0) r = r * 0x80000000000058b90bfbe8e7db95a2f1 >> 127;
    if (x & 0x1000000000000000000 > 0) r = r * 0x8000000000002c5c85fdf473e61ae1f8 >> 127;
    if (x & 0x800000000000000000 > 0) r = r * 0x800000000000162e42fefa39f121751c >> 127;
    if (x & 0x400000000000000000 > 0) r = r * 0x8000000000000b17217f7d1cf815bb96 >> 127;
    if (x & 0x200000000000000000 > 0) r = r * 0x800000000000058b90bfbe8e7bec1e0d >> 127;
    if (x & 0x100000000000000000 > 0) r = r * 0x80000000000002c5c85fdf473dee5f17 >> 127;
    if (x & 0x80000000000000000 > 0) r = r * 0x8000000000000162e42fefa39ef5438f >> 127;
    if (x & 0x40000000000000000 > 0) r = r * 0x80000000000000b17217f7d1cf7a26c8 >> 127;
    if (x & 0x20000000000000000 > 0) r = r * 0x8000000000000058b90bfbe8e7bcf4a4 >> 127;
    if (x & 0x10000000000000000 > 0) r = r * 0x800000000000002c5c85fdf473de72a2 >> 127;
    if (x & 0x8000000000000000 > 0) r = r * 0x80000000000000162e42fefa39ef3765 >> 127;
    if (x & 0x4000000000000000 > 0) r = r * 0x800000000000000b17217f7d1cf79b37 >> 127;
    if (x & 0x2000000000000000 > 0) r = r * 0x80000000000000058b90bfbe8e7bcd7d >> 127;
    if (x & 0x1000000000000000 > 0) r = r * 0x8000000000000002c5c85fdf473de6b6 >> 127;
    if (x & 0x800000000000000 > 0) r = r * 0x800000000000000162e42fefa39ef359 >> 127;
    if (x & 0x400000000000000 > 0) r = r * 0x8000000000000000b17217f7d1cf79ac >> 127;
    if (x & 0x200000000000000 > 0) r = r * 0x800000000000000058b90bfbe8e7bcd6 >> 127;
    if (x & 0x100000000000000 > 0) r = r * 0x80000000000000002c5c85fdf473de6a >> 127;
    if (x & 0x80000000000000 > 0) r = r * 0x8000000000000000162e42fefa39ef35 >> 127;
    if (x & 0x40000000000000 > 0) r = r * 0x80000000000000000b17217f7d1cf79a >> 127;
    if (x & 0x20000000000000 > 0) r = r * 0x8000000000000000058b90bfbe8e7bcd >> 127;
    if (x & 0x10000000000000 > 0) r = r * 0x800000000000000002c5c85fdf473de6 >> 127;
    if (x & 0x8000000000000 > 0) r = r * 0x80000000000000000162e42fefa39ef3 >> 127;
    if (x & 0x4000000000000 > 0) r = r * 0x800000000000000000b17217f7d1cf79 >> 127;
    if (x & 0x2000000000000 > 0) r = r * 0x80000000000000000058b90bfbe8e7bc >> 127;
    if (x & 0x1000000000000 > 0) r = r * 0x8000000000000000002c5c85fdf473de >> 127;
    if (x & 0x800000000000 > 0) r = r * 0x800000000000000000162e42fefa39ef >> 127;
    if (x & 0x400000000000 > 0) r = r * 0x8000000000000000000b17217f7d1cf7 >> 127;
    if (x & 0x200000000000 > 0) r = r * 0x800000000000000000058b90bfbe8e7b >> 127;
    if (x & 0x100000000000 > 0) r = r * 0x80000000000000000002c5c85fdf473d >> 127;
    if (x & 0x80000000000 > 0) r = r * 0x8000000000000000000162e42fefa39e >> 127;
    if (x & 0x40000000000 > 0) r = r * 0x80000000000000000000b17217f7d1cf >> 127;
    if (x & 0x20000000000 > 0) r = r * 0x8000000000000000000058b90bfbe8e7 >> 127;
    if (x & 0x10000000000 > 0) r = r * 0x800000000000000000002c5c85fdf473 >> 127;
    if (x & 0x8000000000 > 0) r = r * 0x80000000000000000000162e42fefa39 >> 127;
    if (x & 0x4000000000 > 0) r = r * 0x800000000000000000000b17217f7d1c >> 127;
    if (x & 0x2000000000 > 0) r = r * 0x80000000000000000000058b90bfbe8e >> 127;
    if (x & 0x1000000000 > 0) r = r * 0x8000000000000000000002c5c85fdf47 >> 127;
    if (x & 0x800000000 > 0) r = r * 0x800000000000000000000162e42fefa3 >> 127;
    if (x & 0x400000000 > 0) r = r * 0x8000000000000000000000b17217f7d1 >> 127;
    if (x & 0x200000000 > 0) r = r * 0x800000000000000000000058b90bfbe8 >> 127;
    if (x & 0x100000000 > 0) r = r * 0x80000000000000000000002c5c85fdf4 >> 127;
    if (x & 0x80000000 > 0) r = r * 0x8000000000000000000000162e42fefa >> 127;
    if (x & 0x40000000 > 0) r = r * 0x80000000000000000000000b17217f7d >> 127;
    if (x & 0x20000000 > 0) r = r * 0x8000000000000000000000058b90bfbe >> 127;
    if (x & 0x10000000 > 0) r = r * 0x800000000000000000000002c5c85fdf >> 127;
    if (x & 0x8000000 > 0) r = r * 0x80000000000000000000000162e42fef >> 127;
    if (x & 0x4000000 > 0) r = r * 0x800000000000000000000000b17217f7 >> 127;
    if (x & 0x2000000 > 0) r = r * 0x80000000000000000000000058b90bfb >> 127;
    if (x & 0x1000000 > 0) r = r * 0x8000000000000000000000002c5c85fd >> 127;
    if (x & 0x800000 > 0) r = r * 0x800000000000000000000000162e42fe >> 127;
    if (x & 0x400000 > 0) r = r * 0x8000000000000000000000000b17217f >> 127;
    if (x & 0x200000 > 0) r = r * 0x800000000000000000000000058b90bf >> 127;
    if (x & 0x100000 > 0) r = r * 0x80000000000000000000000002c5c85f >> 127;
    if (x & 0x80000 > 0) r = r * 0x8000000000000000000000000162e42f >> 127;
    if (x & 0x40000 > 0) r = r * 0x80000000000000000000000000b17217 >> 127;
    if (x & 0x20000 > 0) r = r * 0x8000000000000000000000000058b90b >> 127;
    if (x & 0x10000 > 0) r = r * 0x800000000000000000000000002c5c85 >> 127;
    if (x & 0x8000 > 0) r = r * 0x80000000000000000000000000162e42 >> 127;
    if (x & 0x4000 > 0) r = r * 0x800000000000000000000000000b1721 >> 127;
    if (x & 0x2000 > 0) r = r * 0x80000000000000000000000000058b90 >> 127;
    if (x & 0x1000 > 0) r = r * 0x8000000000000000000000000002c5c8 >> 127;
    if (x & 0x800 > 0) r = r * 0x800000000000000000000000000162e4 >> 127;
    if (x & 0x400 > 0) r = r * 0x8000000000000000000000000000b172 >> 127;
    if (x & 0x200 > 0) r = r * 0x800000000000000000000000000058b9 >> 127;
    if (x & 0x100 > 0) r = r * 0x80000000000000000000000000002c5c >> 127;
    if (x & 0x80 > 0) r = r * 0x8000000000000000000000000000162e >> 127;
    if (x & 0x40 > 0) r = r * 0x80000000000000000000000000000b17 >> 127;
    if (x & 0x20 > 0) r = r * 0x8000000000000000000000000000058b >> 127;
    if (x & 0x10 > 0) r = r * 0x800000000000000000000000000002c5 >> 127;
    if (x & 0x8 > 0) r = r * 0x80000000000000000000000000000162 >> 127;
    if (x & 0x4 > 0) r = r * 0x800000000000000000000000000000b1 >> 127;
    if (x & 0x2 > 0) r = r * 0x80000000000000000000000000000058 >> 127;
    if (x & 0x1 > 0) r = r * 0x8000000000000000000000000000002c >> 127;
    */

    r >>= 127 - (x >> 121);

    return uint128 (r);
  }
}
