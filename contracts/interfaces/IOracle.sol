pragma solidity ^0.6.2;


interface IOracle {
    /// @dev units of collateral per unit of underlying, in RAY
    function get() external view returns (uint256);
}
