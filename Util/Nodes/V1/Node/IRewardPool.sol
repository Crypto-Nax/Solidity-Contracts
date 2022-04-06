// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IRewardPool {
    function addNodeInfo(uint _nftId, address _owner) external returns (bool);
    function updateNodeOwner(uint _nftId, address _owner) external returns (bool);
    function claimReward(uint _nftId) external returns (bool);
}
