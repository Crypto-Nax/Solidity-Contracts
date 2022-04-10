pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
interface Verify {
    function setSniperStatus(address account, bool blacklisted) external;
    function setLpPair(address pair, bool enabled) external;
    function verifyUser(address from, address to) external;
    function checkLaunch(uint256 launchedAt, bool launched, bool protection) external;
    function feeExcluded(address account) external;
    function feeIncluded(address account) external;
    function getCoolDownSettings() external view returns(bool buyCooldown, bool sellCooldown, uint256 coolDownTime, uint256 coolDownLimit);
    function getBlacklistStatus(address account) external view returns(bool);
    function setCooldownEnabled(bool onoff, bool offon) external;
    function setCooldown(uint256 amount) external;
    function updateToken(address token) external;
    function updateRouter(address router) external;
    function getLaunchedAt() external view returns(uint256 launchedAt);
}