pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
interface Verify {
    function setSniperStatus(address account, bool blacklisted) external;
    function setLpPair(address pair, bool enabled) external;
    function verifyUser(address from, address to, uint256 amount) external returns(bool _verified);
    function checkLaunch(uint256 launchedAt, bool launched, bool protection) external;
    function limitedTx(bool onoff) external;
    function feeExcluded(address account, bool excluded) external;
    function setTxSettings(uint256 txp, uint256 txd, uint256 mwp, uint256 mwd, bool limiter) external;
    function getTxSetting() external view returns(uint256 maxTx, uint256 maxWallet, bool limited);
    function getCoolDownSettings() external view returns(bool buyCooldown, bool sellCooldown, uint256 coolDownTime, uint256 coolDownLimit);
    function getBlacklistStatus(address account) external view returns(bool);
    function setCooldownEnabled(bool onoff, bool offon) external;
    function setCooldown(uint256 amount) external;

}