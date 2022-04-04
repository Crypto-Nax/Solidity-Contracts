pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
interface Verify {
    function setSniperStatus(address account, bool blacklisted) external;
    function setLpPair(address pair, bool enabled) external;
    function verifyUser(address from, address to, uint256 amount) external returns(bool _verified);
    function checkLaunch(uint256 launchedAt, bool launched, bool protection) external;
    function limitedTx(bool onoff) external;
    function feeExcluded(address account, bool excluded) external;
}