pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {return msg.sender;}
    function _msgData() internal view virtual returns (bytes memory) {this;return msg.data;}
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }
    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

// pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}


// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Token is Context, IERC20, Ownable {
    using Address for address;
    
    string _name = "Token";
    string _symbol = "Token";
    uint8 _decimals = 9;

    address burnAddress = 0x000000000000000000000000000000000000dEaD;
    address payable _marketingWallet;
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    address public tokenAddress = address(this);

    mapping (address => uint256) _rOwned;
    mapping (address => uint256) _tOwned;
    mapping (address => uint256) buycooldown;    
    mapping (address => uint256) sellcooldown;
    mapping (address => mapping (address => uint256)) _allowances;
    mapping (address => bool) _isExcludedFromFee;
    mapping (address => bool) _isExcluded;
    mapping (address => bool) _isBlacklisted;
    address[] _excluded;

    uint256 constant MAX = ~uint256(0);
    uint256 public initialsupply = 500_000_000_000;
    uint256 _tTotal = initialsupply * 10 ** _decimals; 
    uint256 _rTotal = (MAX - (MAX % _tTotal));
    uint256 _tFeeTotal;

    struct BuyFee{
        uint256 _buytaxFee;
        uint256 _buyliquidityFee;
        uint256 _buyburnFee;}

    BuyFee public BuyFees = BuyFee({
        _buytaxFee: 3,
        _buyliquidityFee: 5,
        _buyburnFee: 2});

    uint256 _previousBuyLiquidityFee = BuyFees._buyliquidityFee;
    uint256 _previousBuyTaxFee = BuyFees._buytaxFee;
    uint256 _previousBuyBurnFee = BuyFees._buyburnFee;
    
    struct Fee{
        uint256 _taxFee;
        uint256 _liquidityFee;
        uint256 _burnFee;}

    Fee public Fees = Fee({
        _taxFee: 3,
        _liquidityFee: 5,
        _burnFee: 2});

    uint256 _previousLiquidityFee = Fees._liquidityFee;
    uint256 _previousTaxFee = Fees._taxFee;
    uint256 _previousBurnFee = Fees._burnFee;

    struct maxFee{
        uint256 maxTaxFee;
        uint256 maxLiquidityFee;
        uint256 maxBurnFee;}

    maxFee public maxFees = maxFee({
        maxTaxFee: 5,
        maxLiquidityFee: 5,
        maxBurnFee: 5});

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;
    bool ContractSwap = block.timestamp >= lastSwap + swapInterval;
    uint256 lastSwap;
    uint256 swapInterval = 10 seconds;
    uint256 numTokensSellToAddToLiquidity =  _tTotal / 10**3;

    struct cooldown{
        bool buycooldownEnabled;
        bool sellcooldownEnabled;
        uint256 _cooldown;
        uint256 _cooldownCap;}

    cooldown public cooldownInfo = cooldown({
        buycooldownEnabled: false,
        sellcooldownEnabled: false,
        _cooldown: 30 seconds,
        _cooldownCap: 60 seconds});

    bool public maxTxEnabled = false;
    uint256 public _maxBuyAmount;
    uint256 public _maxSellAmount;
    bool takeFee;
    bool public noFees;
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event launched();
    struct Launch{
        bool Launched;
        bool LaunchProtection;
        uint256 LaunchedAt;
        uint256 snipeBlockAmount;}

    Launch public wenLaunch = Launch({
        Launched: false,
        LaunchProtection: false,
        LaunchedAt: 0,
        snipeBlockAmount: 0});

    event ToMarketing(uint256 bnbSent);
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    constructor () {
        _rOwned[_msgSender()] = _rTotal;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[burnAddress] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }
    function initialize(address payable m, uint256 amount, uint256 percent) public onlyOwner{
        require(!wenLaunch.Launched);
        _marketingWallet = (m);
        wenLaunch.snipeBlockAmount = amount;
        _maxBuyAmount = (_tTotal * percent) / 10**3;
        _maxSellAmount = _maxBuyAmount / 2;
        swapAndLiquifyEnabled = true;
        maxTxEnabled = true;
        cooldownInfo.buycooldownEnabled = true;
        cooldownInfo.sellcooldownEnabled = true;
        wenLaunch.LaunchProtection = true;
    }

    receive() external payable {}
    function name() public view returns (string memory) {return _name;}
    function symbol() public view returns (string memory) {return _symbol;}
    function decimals() public view returns (uint8) {return _decimals;}
    function totalSupply() public view override returns (uint256) {return _tTotal;}
    function balanceOf(address account) public view override returns (uint256) {if (_isExcluded[account]) return _tOwned[account];return tokenFromReflection(_rOwned[account]);}
    function transfer(address recipient, uint256 amount) public override returns (bool) {_transfer(_msgSender(), recipient, amount);return true;}
    function allowance(address owner, address spender) public view override returns (uint256) {return _allowances[owner][spender];}
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {_approve(_msgSender(), spender, _allowances[_msgSender()][spender] += (addedValue));return true;}
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {_approve(_msgSender(), spender, _allowances[_msgSender()][spender] -= subtractedValue);return true;}
    function approve(address spender, uint256 amount) public override returns (bool) {_approve(_msgSender(), spender, amount);return true;}
    function totalFees() public view returns (uint256) {return _tFeeTotal;}
    function setNumTokensSellToAddToLiquidity(uint256 amount,bool _enabled) public onlyOwner() {numTokensSellToAddToLiquidity = (_tTotal * amount) / 10000 ;swapAndLiquifyEnabled = _enabled;emit SwapAndLiquifyEnabledUpdated(_enabled);}
    function setCooldownEnabled(bool onoff, bool truefalse, uint256 time) public onlyOwner() {require(time <= cooldownInfo._cooldownCap); cooldownInfo._cooldown = time;cooldownInfo.buycooldownEnabled = onoff;cooldownInfo.sellcooldownEnabled = truefalse;}
    function setSwapInteral(uint256 interval) public onlyOwner() {swapInterval = interval;}
    function setMaxBuyPercent(uint256 _mtxp, bool _mtx) external onlyOwner() {require(_mtxp >= 1); _maxBuyAmount = _tTotal * (_mtxp) / (10**3); _maxSellAmount = _maxBuyAmount / 2; maxTxEnabled = _mtx;}
    function excludeFromFee(address account) public onlyOwner {_isExcludedFromFee[account] = true;}
    function includeInFee(address account) public onlyOwner {_isExcludedFromFee[account] = false;}
    function isExcludedFromFee(address account) public view returns(bool) {return _isExcludedFromFee[account];}
    function setBlacklistStatus(address account, bool Blacklisted) external onlyOwner {if (Blacklisted = true) {_isBlacklisted[account] = true; } else if(Blacklisted = false) {_isBlacklisted[account] = false;}}
    function isBlacklisted(address account) public view returns(bool) {return _isBlacklisted[account];}
    function isExcludedFromReward(address account) public view returns (bool) {return _isExcluded[account];}
    function excludeFromReward(address account) public onlyOwner() {require(!_isExcluded[account], "Account is already excluded"); if(_rOwned[account] > 0) {_tOwned[account] = tokenFromReflection(_rOwned[account]);}_isExcluded[account] = true;_excluded.push(account);}
    function includeInReward(address account) external onlyOwner() {require(_isExcluded[account], "Account is already excluded");for (uint256 i = 0; i < _excluded.length; i++) {if (_excluded[i] == account) {_excluded[i] = _excluded[_excluded.length - 1];_tOwned[account] = 0;_isExcluded[account] = false;_excluded.pop();break;}}}
    function clearStuckTokens(address _token, address _to) external onlyOwner returns (bool _sent){require(_token != address(0));if(_token == uniswapV2Pair){require((block.number - wenLaunch.LaunchedAt) >= (wenLaunch.LaunchedAt + 201600));} else {uint256 _contractBalance = IERC20(_token).balanceOf(address(this));_sent = IERC20(_token).transfer(_to, _contractBalance);}}
    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {require(amountPercentage <= 100);uint256 amountBNB = address(this).balance;payable(_marketingWallet).transfer(amountBNB * amountPercentage / 100);}
    function setFees(uint256 taxFee, uint256 liquidityFee, uint256 burnFee) external onlyOwner() {require(taxFee <= maxFees.maxTaxFee && liquidityFee <= maxFees.maxLiquidityFee && burnFee <= maxFees.maxBurnFee);require(taxFee + liquidityFee + burnFee <= 1500);Fees._taxFee = taxFee;Fees._liquidityFee = liquidityFee;Fees._burnFee = burnFee;}
    function setBuyFees(uint256 taxFee, uint256 liquidityFee, uint256 burnFee) external onlyOwner() {require(taxFee <= maxFees.maxTaxFee && liquidityFee <= maxFees.maxLiquidityFee && burnFee <= maxFees.maxBurnFee);require(taxFee + liquidityFee + burnFee <= 1500);BuyFees._buytaxFee = taxFee;BuyFees._buyliquidityFee = liquidityFee;BuyFees._buyburnFee = burnFee;}
    function _reflectFee(uint256 rFee, uint256 tFee) private {_rTotal = _rTotal -= (rFee);_tFeeTotal = _tFeeTotal += (tFee);}
    function restoreAllFee() private {Fees._taxFee = _previousTaxFee;Fees._liquidityFee = _previousLiquidityFee;Fees._burnFee = _previousBurnFee;BuyFees._buyburnFee = _previousBuyBurnFee;BuyFees._buyliquidityFee = _previousBuyLiquidityFee;BuyFees._buytaxFee = _previousBuyTaxFee;}
    function removeAllFee() private {if(Fees._taxFee == 0 && Fees._liquidityFee == 0 && Fees._burnFee == 0 && BuyFees._buytaxFee == 0 && BuyFees._buyliquidityFee == 0 && BuyFees._buyburnFee == 0) return;_previousTaxFee = Fees._taxFee;_previousLiquidityFee = Fees._liquidityFee;_previousBurnFee = Fees._burnFee;_previousBuyBurnFee = BuyFees._buyburnFee;_previousBuyTaxFee = BuyFees._buytaxFee;_previousBuyLiquidityFee = BuyFees._buyliquidityFee;BuyFees._buyliquidityFee = 0;BuyFees._buyburnFee = 0;BuyFees._buytaxFee = 0;Fees._burnFee = 0;Fees._taxFee = 0;Fees._liquidityFee = 0;}
    function areFeesOn(bool onoff, bool truefalse) public onlyOwner {noFees = onoff; takeFee = truefalse;}
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] -= (amount));
        return true;
    }
    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _rTotal = _rTotal -= (rAmount);
        _tFeeTotal = _tFeeTotal += (tAmount);
    }
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount / (currentRate);
    }
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, tBurn, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tBurn);
    }
    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = (tAmount * Fees._taxFee) / 10**2;
        uint256 tLiquidity = (tAmount * Fees._liquidityFee) / 10**2;
        uint256 tBurn = (tAmount * Fees._burnFee) / 10**2;
        uint256 tTransferAmount = tAmount -= (tFee + tLiquidity);
        return (tTransferAmount, tFee, tLiquidity, tBurn);
    }
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * (currentRate);
        uint256 rFee = tFee * (currentRate);
        uint256 rBurn = tBurn * (currentRate);
        uint256 rLiquidity = tLiquidity * (currentRate);
        uint256 rTransferAmount = rAmount -= (rFee + rLiquidity + rBurn);
        return (rAmount, rTransferAmount, rFee);
    }
    function _getBuyValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getBuyTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getBuyRValues(tAmount, tFee, tLiquidity, tBurn, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tBurn);
    }
    function _getBuyTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = (tAmount * BuyFees._buytaxFee) / 10**2;
        uint256 tLiquidity = (tAmount * BuyFees._buyliquidityFee) / 10**2;
        uint256 tBurn = (tAmount * BuyFees._buyburnFee) / 10**2;
        uint256 tTransferAmount = tAmount -= (tFee + tLiquidity);
        return (tTransferAmount, tFee, tLiquidity, tBurn);
    }
    function _getBuyRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * (currentRate);
        uint256 rFee = tFee * (currentRate);
        uint256 rBurn = tBurn * (currentRate);
        uint256 rLiquidity = tLiquidity * (currentRate);
        uint256 rTransferAmount = rAmount -= (rFee + rLiquidity + rBurn);
        return (rAmount, rTransferAmount, rFee);
    }
    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / (tSupply);
    }
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply -= (_rOwned[_excluded[i]]);
            tSupply = tSupply -= (_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal / (_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity * (currentRate);
        _rOwned[address(this)] = _rOwned[address(this)] += (rLiquidity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] += (tLiquidity);
    }
    function _takeBurn(uint256 tBurn) private {
        _tOwned[address(burnAddress)] = _tOwned[address(burnAddress)] += (tBurn);
    }
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function checkBuy(address from,address to,uint256 amount) private {
        if (from == uniswapV2Pair && to != address(uniswapV2Router) && !_isExcludedFromFee[to] && cooldownInfo.buycooldownEnabled) {
                require(amount <= _maxBuyAmount, "Transfer amount exceeds the Max Buy Amount.");
                require(buycooldown[to] < block.timestamp, "Buy Cooldown not over");
                buycooldown[to] = block.timestamp + (cooldownInfo._cooldown);}
    }
    function checkSell(address from,uint256 amount) private {
        if (from != uniswapV2Pair && cooldownInfo.sellcooldownEnabled && !_isExcludedFromFee[from]) {
            require(amount <= _maxSellAmount, "Transfer amount exceeds the Max Sell Amount");
            require(sellcooldown[from] <= block.timestamp, "Sell Cooldown not over");
            sellcooldown[from] = block.timestamp + (cooldownInfo._cooldown);}
    }
    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != uniswapV2Pair
            && !inSwapAndLiquify
            && swapAndLiquifyEnabled
            && _tOwned[address(this)] >= numTokensSellToAddToLiquidity
            && ContractSwap;
    }   
    function shouldTakeFee(address from, address to) private {
        require(!noFees);
        takeFee = true;
        if(!_isExcludedFromFee[from] || !_isExcludedFromFee[to]) {
            takeFee = false;
        }
    }        
    function checkLaunched(address from) internal view {
            require(wenLaunch.Launched || _isExcludedFromFee[from], "Pre-Launch Protection");
        }           
    function launch() private {
            wenLaunch.LaunchedAt = block.number;
            wenLaunch.Launched = true;
            emit launched();
        } 
    function checkLP(address from, address to) private {
        require(!wenLaunch.Launched);
        if(_isExcludedFromFee[from] && to == uniswapV2Pair){
            require(_tOwned[from] > 0); 
            launch();
        } else if(!_isExcludedFromFee[from]){
            revert();
        }
    }    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(_isBlacklisted[from] == false, "Hehe");
        require(_isBlacklisted[to] == false, "Hehe");
        checkLaunched(from);
        if(wenLaunch.LaunchProtection){
            if(!wenLaunch.Launched){
                checkLP(from, to);
                } else {
                    if(wenLaunch.LaunchedAt > 0 
                    && from == uniswapV2Pair
                    && !_isExcludedFromFee[to]){
                        if(block.number - wenLaunch.LaunchedAt <= wenLaunch.snipeBlockAmount){_isBlacklisted[to] = true;
                        } else {
                            if(block.number - wenLaunch.LaunchedAt >= wenLaunch.snipeBlockAmount){
                                wenLaunch.LaunchProtection = false;
                            }
                        }
                    }
                }
            }
        if(maxTxEnabled){checkBuy(from, to, amount); checkSell(from, amount);}    
        if(shouldSwapBack()) {swapAndLiquify(numTokensSellToAddToLiquidity);lastSwap = block.timestamp;}
        if(!noFees){shouldTakeFee(from, to);}
        _tokenTransfer(from,to,amount);
    }
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 marketingTokenBalance = contractTokenBalance / (2);
        uint256 liquidityTokenBalance = contractTokenBalance -= (marketingTokenBalance);
        uint256 tokenBalanceToLiquifyAsBNB = liquidityTokenBalance / (2);
        uint256 tokenBalanceToLiquify = liquidityTokenBalance -= (tokenBalanceToLiquifyAsBNB);
        uint256 initialBalance = address(this).balance;
        uint256 tokensToSwapToBNB = tokenBalanceToLiquifyAsBNB += (marketingTokenBalance);
        swapTokensForEth(tokensToSwapToBNB);
        uint256 bnbSwapped = address(this).balance - (initialBalance);
        uint256 bnbToLiquify = bnbSwapped / (3);
        addLiquidity(tokenBalanceToLiquify, bnbToLiquify);
        emit SwapAndLiquify(tokenBalanceToLiquifyAsBNB, bnbToLiquify, tokenBalanceToLiquify);
        uint256 marketingBNB = bnbSwapped -= (bnbToLiquify);
        _marketingWallet.transfer(marketingBNB);
        emit ToMarketing(marketingBNB);
    }
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            tokenAddress,
            block.timestamp
        );
    }
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if(!takeFee)
            removeAllFee();
        if (sender == uniswapV2Pair && recipient != address(uniswapV2Router)) {
            _transferStandardBuy(sender, recipient, amount);
        } else if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();
        if(!noFees){takeFee = true;}
    }
    function _transferStandardBuy(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn, uint256 tLiquidity) = _getBuyValues(tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _rOwned[recipient] = _rOwned[recipient] += (rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount); 
    }
    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _rOwned[recipient] = _rOwned[recipient] += (rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _tOwned[recipient] = _tOwned[recipient] += (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient] += (rTransferAmount);
        _takeLiquidity(tLiquidity);
        _takeBurn(tBurn);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] -=(tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _rOwned[recipient] = _rOwned[recipient] += (rTransferAmount);        
        _takeBurn(tBurn);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] -= (tAmount);
        _rOwned[sender] = _rOwned[sender] -= (rAmount);
        _tOwned[recipient] = _tOwned[recipient] += (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient] += (rTransferAmount);
        _takeBurn(tBurn);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}