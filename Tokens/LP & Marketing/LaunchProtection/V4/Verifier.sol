pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
import "./IERC20MetaData.sol";
import "./Verify.sol";
import "./Ownable.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";
import "./Address.sol";

contract Verifier is Verify{
    using Address for address;
    mapping (address => bool) lpPairs;
    mapping(address => uint256) private buycooldown;
    mapping(address => uint256) private sellcooldown;
    mapping(address => bool) public _isBlacklisted;
    mapping(address => bool) public _isExcludedFromFee;
    address _token;
    IUniswapV2Router02 public uniswapV2Router;
    modifier onlyToken() {
        require(msg.sender == _token); _;
    }
    struct ILaunch {
        uint256 launchedAt;
        uint256 antiBlocks;
        bool launched;
        bool launchProtection;
    }
    ILaunch public wenLaunch;

    struct Icooldown {
        bool buycooldownEnabled;
        bool sellcooldownEnabled;
        uint256 cooldown;
        uint256 cooldownLimit;
    }
    Icooldown public cooldownInfo =
        Icooldown({
            buycooldownEnabled: true,
            sellcooldownEnabled: true,
            cooldown: 30 seconds,
            cooldownLimit: 60 seconds
        });


    constructor(address[4] memory addresses) {
        uniswapV2Router = IUniswapV2Router02(addresses[2]);
        _token = addresses[0];
        _isExcludedFromFee[addresses[0]] = true;
        _isExcludedFromFee[addresses[1]] = true;
        lpPairs[addresses[3]] = true;
    }
    
    function updateToken(address token) external override onlyToken {
        _token = token;
    }

    function updateRouter(address router) external override onlyToken {
        uniswapV2Router = IUniswapV2Router02(router);
    }

    function feeExcluded(address account) external override onlyToken {
        _isExcludedFromFee[account] = true;
    }

    function feeIncluded(address account) external override onlyToken {
        _isExcludedFromFee[account] = false;
    }

    function getCoolDownSettings() public view override returns(bool, bool, uint256, uint256) {
        return(cooldownInfo.buycooldownEnabled, cooldownInfo.sellcooldownEnabled, cooldownInfo.cooldown, cooldownInfo.cooldownLimit);
    }
        
    function getBlacklistStatus(address account) external view override returns(bool) {
        return _isBlacklisted[account];
    }

    function setCooldownEnabled(bool onoff, bool offon) external override onlyToken {
        cooldownInfo.buycooldownEnabled = onoff;
        cooldownInfo.sellcooldownEnabled = offon;
    }

    function setCooldown(uint256 amount) external override onlyToken {
        require(amount <= cooldownInfo.cooldownLimit);
        cooldownInfo.cooldown = amount;
    }

    function setSniperStatus(address account, bool blacklisted) external override onlyToken {
        _setSniperStatus(account, blacklisted);
    }

    function _setSniperStatus(address account, bool blacklisted) internal {
        if(lpPairs[account] || account == address(_token) || account == address(uniswapV2Router) || _isExcludedFromFee[account]) {revert();}
        
        if (blacklisted == true) {
            _isBlacklisted[account] = true;
        } else {
            _isBlacklisted[account] = false;
        }    
    }

    function getLaunchedAt() external override view returns(uint256 launchedAt){
        return wenLaunch.launchedAt;
    }

    function checkLaunch(uint256 launchedAt, bool launched, bool protection, uint256 blockAmount) external override onlyToken {
        wenLaunch.launchedAt = launchedAt;
        wenLaunch.launched = launched;
        wenLaunch.launchProtection = protection;
        wenLaunch.antiBlocks = blockAmount;
    }

    function setLpPair(address pair, bool enabled) external override onlyToken {
        lpPairs[pair] = enabled;
    }

    function verifyUser(address from, address to) public override onlyToken {
        require(!_isBlacklisted[to]);
        require(!_isBlacklisted[from]);
        if (wenLaunch.launchProtection) {
            if (lpPairs[from] && to != address(uniswapV2Router) && !_isExcludedFromFee[to]) {
                if (block.number <= wenLaunch.launchedAt + wenLaunch.antiBlocks) {
                    _setSniperStatus(to, true);
              }
            } else {
                wenLaunch.launchProtection = false;
            }
        }
        if (lpPairs[from] && to != address(uniswapV2Router) && !_isExcludedFromFee[to] && cooldownInfo.buycooldownEnabled) {
            require(buycooldown[to] < block.timestamp);
            buycooldown[to] = block.timestamp + (cooldownInfo.cooldown);
            } else if (!lpPairs[from] && !_isExcludedFromFee[from] && cooldownInfo.sellcooldownEnabled){
                require(sellcooldown[from] <= block.timestamp);
                sellcooldown[from] = block.timestamp + (cooldownInfo.cooldown);
            } 
    }
}