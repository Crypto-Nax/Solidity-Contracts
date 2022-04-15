//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

interface Staking {
    function stakedTokens(address user) external returns (uint256);
}
