pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed

interface ILocker {
    function getUnlockTime() external view returns(uint256);
    function getId() external view returns(uint256);
    function getTotalTokenBalance() external view returns (uint256);
    function getLpAddress() external view returns(address);
    function extendLock(uint256 newUnlockTime) external returns(bool extended);
    function withdrawTokens() external returns(bool);
    function transferLockOwnership(address _lockOwner) external returns(bool transferred);
    function increaseLockAmount(uint256 amount) external returns(bool increased);
}