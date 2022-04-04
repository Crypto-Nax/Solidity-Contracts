pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
import "./IERC20.sol";
import "./Verify.sol";
import "./Ownable.sol";
import "./Context.sol";

contract Verifier is Context, Verify, Ownable{
    address _token;
    address public  uniswapV2Router;
    mapping (address => bool) lpPairs;
    mapping(address => bool) Tokens;
    mapping(address => uint256) private buycooldown;
    mapping(address => uint256) private sellcooldown;
    mapping(address => bool) public _isBlacklisted;
    mapping(address => bool) public _isExcludedFromFee;
    IERC20 Token;

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }
    struct ILaunch {
        uint256 launchedAt;
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

    struct ItxSettings {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        bool txLimits;
    }

    ItxSettings public txSettings;

    constructor(address token) {
        Token = IERC20(token);
        _token = token;
        setTxSettings(1, 100, 2, 100, true);
    }
    
    function feeExcluded(address account, bool excluded) external override onlyToken {
        if(excluded == true) {
            _isExcludedFromFee[account] = true;
        } else {
            _isExcludedFromFee[account] = false;
        }
    }

    function limitedTx(bool onoff) public override onlyToken {
        if(onoff == true) {
        txSettings.txLimits = true;
        } else {
        txSettings.txLimits = false;
        }
    }

    function getTxSetting() public view override returns(uint256, uint256, bool){
        return (txSettings.maxTxAmount, txSettings.maxWalletAmount, txSettings.txLimits);
    }

    function getCoolDownSettings() public view override returns(bool, bool, uint256, uint256) {
        return(cooldownInfo.buycooldownEnabled, cooldownInfo.sellcooldownEnabled, cooldownInfo.cooldown, cooldownInfo.cooldownLimit);
    }

    function getBlacklistStatus(address account) public view override returns(bool) {
        return _isBlacklisted[account];
    }
    function setCooldownEnabled(bool onoff, bool offon) external onlyOwner {
        cooldownInfo.buycooldownEnabled = onoff;
        cooldownInfo.sellcooldownEnabled = offon;
    }

    function setCooldown(uint256 amount) external onlyOwner {
        require(amount <= cooldownInfo.cooldownLimit);
        cooldownInfo.cooldown = amount;
    }

    function checkTokens(address token) public view returns(bool){
        return Tokens[token];
    }

    function setTxSettings(uint256 txp, uint256 txd, uint256 mwp, uint256 mwd, bool limiter) public override onlyOwner {
        require((Token.totalSupply() * txp) / txd >= (Token.totalSupply()/ 1000), "Max Transaction must be above 0.1% of total supply.");
        require((Token.totalSupply()* mwp) / mwd >= (Token.totalSupply() / 1000), "Max Wallet must be above 0.1% of total supply.");
        uint256 newTx = (Token.totalSupply() * txp) / (txd);
        uint256 newMw = (Token.totalSupply() * mwp) / mwd;
        txSettings = ItxSettings ({
            maxTxAmount: newTx,
            maxWalletAmount: newMw,
            txLimits: limiter
        });
    }

    function setSniperStatus(address account, bool blacklisted) public override  {
        require(msg.sender == _token || msg.sender == owner());
        if(lpPairs[account] || account == address(Token) || account == address(uniswapV2Router)) {revert();}
        
        if (blacklisted == true) {
            _isBlacklisted[account] = true;
        } else {
            _isBlacklisted[account] = false;
        }    }

    function checkLaunch(uint256 launchedAt, bool launched, bool protection) external override onlyToken {
        wenLaunch.launchedAt = launchedAt;
        wenLaunch.launched = launched;
        wenLaunch.launchProtection = protection;
    }

    function setLpPair(address pair, bool enabled) external override onlyToken {
        if (enabled == false) {
            lpPairs[pair] = false;
        } else {
            lpPairs[pair] = true;
        }
    }

    function verifyUser(address from, address to, uint256 amount) external override onlyToken returns(bool _verified) {
        if (txSettings.txLimits) {
            if(from != owner() && to != owner() && to != address(0xdead)) 
            {
                if (lpPairs[from] || lpPairs[to]) {
                    if(!_isExcludedFromFee[to] && !_isExcludedFromFee[from]) {
                        require(amount <= txSettings.maxTxAmount);
                    }
                }
                if(to != address(uniswapV2Router) && !lpPairs[to]) {
                    if(!_isExcludedFromFee[to]) {
                        require(Token.balanceOf(to) + amount <= txSettings.maxWalletAmount);
                    }
                }
            }
        }

        if (wenLaunch.launchProtection) {
            if (block.number <= (wenLaunch.launchedAt + 2)) {
                if (
                    lpPairs[from] &&
                    to != address(uniswapV2Router) &&
                    !_isExcludedFromFee[to]
                ) {
                    setSniperStatus(to, true);
                    return false;
                }
            } else {
                wenLaunch.launchProtection = false;
            }
        }
        if(_isBlacklisted[to]){
            return false;
        }
        if(_isBlacklisted[from]){
            return false;
        }
        if (lpPairs[from] && to != address(uniswapV2Router) && !_isExcludedFromFee[to]
            ) {
                if (cooldownInfo.buycooldownEnabled) {
                    require(buycooldown[to] < block.timestamp);
                    buycooldown[to] = block.timestamp + (cooldownInfo.cooldown);
                }
            } else if (!lpPairs[from] && !_isExcludedFromFee[from]){
                if (cooldownInfo.sellcooldownEnabled) {
                    require(sellcooldown[from] <= block.timestamp);
                    sellcooldown[from] = block.timestamp + (cooldownInfo.cooldown);
                }
            } 
        return true;
        }
}