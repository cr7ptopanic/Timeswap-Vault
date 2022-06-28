// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./ILend.sol";
import "./IWithdraw.sol";
import "./IPair.sol";

interface IConvenience is ILend, IWithdraw, IPair {
    /// @dev Calls the lend function and deposit asset into a pool.
    /// @dev Calls given percentage ratio of bond and insurance.
    /// @dev Must have the asset ERC20 approve this contract before calling this function.
    /// @param params The parameters for this function found in ILend interface.
    /// @return assetIn The amount of asset ERC20 deposited.
    /// @return claimsOut The amount of bond ERC20 and insurance ERC20 received by bondTo and insuranceTo.
    function lendGivenPercent(LendGivenPercent calldata params)
        external
        returns (uint256 assetIn, IPair.Claims memory claimsOut);

    /// @dev Calls the withdraw function and withdraw asset and collateral from a pool.
    /// @param params The parameters for this function found in IWithdraw interface.
    /// @return tokensOut The amount of asset ERC20 and collateral ERC20 received by assetTo and collateralTo.
    function collect(Collect calldata params)
        external
        returns (IPair.Tokens memory tokensOut);
}
