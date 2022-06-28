// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPair {
    struct Claims {
        uint112 bondPrincipal;
        uint112 bondInterest;
        uint112 insurancePrincipal;
        uint112 insuranceInterest;
    }

    struct Tokens {
        uint128 asset;
        uint128 collateral;
    }
}
