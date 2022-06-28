// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILend {
    struct LendGivenPercent {
        IERC20 asset;
        IERC20 collateral;
        uint256 maturity;
        address bondTo;
        address insuranceTo;
        uint112 assetIn;
        uint40 percent;
        uint128 minBond;
        uint128 minInsurance;
        uint256 deadline;
    }
}
