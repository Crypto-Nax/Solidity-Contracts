//SPDX-License-Identifier: Unlicensed
pragma solidity >=0.5.0 <0.9.0;

abstract contract Context {
    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
    
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
    
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
    
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
    
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    
        return c;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

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

    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

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

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution,uint256 _minHoldReq) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit() external payable;
    function process(uint256 gas) external;        
    function claimDividendFor(address shareholder) external;
    function holdReq() external view returns(uint256);
    function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256);
    function getAccountInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256);
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;
    
    address _token;
    
    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IUniswapV2Router02 router;
    
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;
    mapping (address => Share) public shares;
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    
    uint256 public minPeriod = 1 minutes; // amount of time for min distribution to accumalate, once over it sends after x amount automatically.
    uint256 public minHoldReq = 100 * (10**9); // 100 tokens for rewards
    uint256 public minDistribution = 0.01 * (10 ** 18); // .01 token with 18 decimals reward for auto claim
    
    uint256 currentIndex;
    
    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }
    
    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (address _router) {
        _token = msg.sender;
        router = IUniswapV2Router02(_router);
    }

    function start(address Tinitializer)public onlyToken{
        _token = address(Tinitializer);
    }
    
    function getShareholderInfo(address shareholder) external view override returns (uint256, uint256, uint256, uint256) {
        return (
            totalShares,
            totalDistributed,
            shares[shareholder].amount,
            shares[shareholder].totalRealised             
        );
    }

    function holdReq() external view override returns(uint256) {
        return minHoldReq;
    }

    function getAccountInfo(address shareholder) external view override returns(
        uint256 pendingReward,
        uint256 lastClaimTime,
        uint256 nextClaimTime,
        uint256 secondsUntilAutoClaimAvailable){
            
        pendingReward = getUnpaidEarnings(shareholder);
        lastClaimTime = shareholderClaims[shareholder];
        nextClaimTime = lastClaimTime + minPeriod;
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ? nextClaimTime.sub(block.timestamp) : 0;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldReq) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
        minHoldReq = _minHoldReq * (10**9);
        emit DistributionCriteriaUpdated(minPeriod, minDistribution, minHoldReq);
    }
    
    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
        distributeDividend(shareholder);
            }
    
        if(amount > minHoldReq && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount <= minHoldReq && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }
    
        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
            
        emit ShareUpdated(shareholder, amount);
    }
    
    function deposit() external payable override {

        uint256 amount = msg.value;
    
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
            
        emit Deposit(amount);
    }
    
    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;
    
        if(shareholderCount == 0) { return; }
    
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
    
        uint256 iterations = 0;
        uint256 count = 0;
    
        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }
    
            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
                count++;
            }
    
            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
            
        emit DividendsProcessed(iterations, count, currentIndex);
    }
    
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
        && getUnpaidEarnings(shareholder) > minDistribution;
    }
    
    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }
        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0){
            totalDistributed = totalDistributed.add(amount);
            payable(shareholder).transfer(amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
                        
            emit Distribution(shareholder, amount);
        }
    }


    function claimDividend() public {
        distributeDividend(msg.sender);
    }
    
    function claimDividendFor(address shareholder) public override {
        distributeDividend(shareholder);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }
    
        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;
    
        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }
    
        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }
    
    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }
    
    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }
    
    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
        
    event DistributionCriteriaUpdated(uint256 minPeriod, uint256 minDistribution, uint256 minHoldReq);
    event ShareUpdated(address shareholder, uint256 amount);
    event Deposit(uint256 amountBNB);
    event Distribution(address shareholder, uint256 amount);
    event DividendsProcessed(uint256 iterations, uint256 count, uint256 index);
}

contract ApexVentures is IERC20, Context {
    address public owner;
    address public autoLiquidityReceiver;
    address public treasuryFeeReceiver;
    address public pair;

    string constant _name = "Apex Ventures";
    string constant _symbol = "$APEX";

    uint256 constant _initialSupply = 100_000_000; // put supply amount here
    uint256 _totalSupply = _initialSupply * (10**_decimals); // total supply amount
    uint256 treasuryFees;
    uint256 manualDepositAmount;
    uint32 distributorGas = 500000;
    uint16 feeDenominator = 100;
    uint16 totalFee;
    uint8 constant _decimals = 9;

    bool public feeEnabled;
    bool public autoClaimEnabled;
    bool public fundRewards;
    bool public tradingOpen;
    bool manualDeposit;
    mapping(address => bool) public lpPairs;    
    mapping(address => bool) public lpHolder;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => uint256) cooldown;
    mapping(address => bool) isFeeExempt;
    mapping(address => bool) maxWalletExempt;
    mapping(address => bool) isDividendExempt;
    mapping(address => bool) public bannedUsers;
    mapping(address => bool) authorizations;
    struct IFees {
        uint16 liquidityFee;
        uint16 reflectionFee;
        uint16 treasuryFee;
        uint16 totalFee;
    }
    struct ICooldown {
        bool buycooldownEnabled;
        bool sellcooldownEnabled;
        uint8 cooldownLimit;
        uint8 cooldownTime;
    }
    struct ILiquiditySettings {
        uint256 liquidityFeeAccumulator;
        uint256 numTokensToSwap;
        uint256 lastSwap;
        uint8 swapInterval;
        bool swapEnabled;
        bool marketing;
        bool inSwap;
        bool autoLiquifyEnabled;
    }
    struct ILaunch {
        uint256 launchBlock;
        uint8 antiBlocks;
        bool launched;
        bool launchProtection;
    }
    struct ITransactionSettings {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        bool txLimits;
    }        
    IUniswapV2Router02 public router;
    IDividendDistributor public distributor;
    ILiquiditySettings public LiquiditySettings;
    ICooldown public cooldownInfo;    
    ILaunch public Launch;
    ITransactionSettings public TransactionSettings;
    IFees public BuyFees;
    IFees public SellFees;
    IFees public MaxFees;
    IFees public TransferFees;
    modifier swapping() {
        LiquiditySettings.inSwap = true;
        _;
        LiquiditySettings.inSwap = false;
    }
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    constructor() {
        owner = _msgSender();
        authorizations[owner] = true;
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IUniswapV2Factory(router.factory()).createPair(router.WETH(), address(this));
        lpPairs[pair] = true;
        lpHolder[_msgSender()] = true;
        _allowances[address(this)][address(router)] = type(uint256).max;
        _allowances[_msgSender()][address(router)] = type(uint256).max;

        distributor = new DividendDistributor(address(router));

        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;

        maxWalletExempt[msg.sender] = true;
        maxWalletExempt[address(this)] = true;
        maxWalletExempt[pair] = true;

        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[address(0xDead)] = true;
        setFeeReceivers(0xDA592C277aEF5f3508f2Cb37B17dEfA82acA4199,0x4Eb5fe2aC1ab4e9Ea882f20845F12Ee652f9D74e);
        cooldownInfo.cooldownLimit = 60; // cooldown cannot go over 60 seconds
        MaxFees = IFees({
            reflectionFee: 10,
            liquidityFee: 5,
            treasuryFee: 15,
            totalFee: 30 // 30%
        });

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function setLpPair(address _pair, bool enabled) external onlyOwner{
        lpPairs[_pair] = enabled;
    }

    function setLpHolder(address holder, bool enabled) public onlyOwner{
        lpHolder[holder] = enabled;
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    function symbol() external pure override returns (string memory) {
        return _symbol;
    }

    function name() external pure override returns (string memory) {
        return _name;
    }

    function getOwner() external view override returns (address) {
        return owner;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address sender, address spender, uint256 amount) private {
        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function limits(address from, address to) private view returns (bool) {
        return !isOwner(from)
            && !isOwner(to)
            && tx.origin != owner
            && !isAuthorized(from)
            && !isAuthorized(to)
            && !lpHolder[from]
            && !lpHolder[to]
            && to != address(0xdead)
            && to != address(0)
            && from != address(this);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool){
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount ) internal returns (bool) {
        if (LiquiditySettings.inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        require(!bannedUsers[sender]);
        require(!bannedUsers[recipient]);
        if(limits(sender, recipient)){
            if(!tradingOpen) checkLaunched(sender);
            if(tradingOpen && TransactionSettings.txLimits){
                if(!maxWalletExempt[recipient]){
                    require(amount <= TransactionSettings.maxTxAmount && balanceOf(recipient) + amount <= TransactionSettings.maxWalletAmount, "TOKEN: Amount exceeds Transaction size");
                }
                if (lpPairs[sender] && recipient != address(router) && !isFeeExempt[recipient] && cooldownInfo.buycooldownEnabled) {
                    require(cooldown[recipient] < block.timestamp);
                    cooldown[recipient] = block.timestamp + (cooldownInfo.cooldownTime);
                } else if (!lpPairs[sender] && !isFeeExempt[sender] && cooldownInfo.sellcooldownEnabled){
                    require(cooldown[sender] <= block.timestamp);
                    cooldown[sender] = block.timestamp + (cooldownInfo.cooldownTime);
                } 

                if(Launch.launched && Launch.launchProtection){
                    if(Launch.launchBlock + Launch.antiBlocks <= block.number) {
                        turnOff();
                    }
                    if (block.number  <= Launch.launchBlock + Launch.antiBlocks) {
                        _setBlacklistStatus(recipient, true);
                    }
                }
            }
        }

        if (shouldSwapBack()) {
            swapBack();
        }

        _balances[sender] = _balances[sender] - amount;

        uint256 amountReceived = shouldTakeFee(sender) ? takeFee(sender, recipient, amount) : amount;

        _balances[recipient] += amountReceived;

        if (!isDividendExempt[sender] && balanceOf(sender) >= holdReq()) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }
        if (!isDividendExempt[recipient] && balanceOf(recipient) >= holdReq() ) {
            try
                distributor.setShare(recipient, _balances[recipient])
            {} catch {}
        }

        if (autoClaimEnabled) {
            try distributor.process(distributorGas) {} catch {}
        }

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function checkLaunched(address sender) internal view {
        require(tradingOpen || isAuthorized(sender), "Pre-Launch Protection");
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return feeEnabled && !isFeeExempt[sender];
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        if (isFeeExempt[sender] || isFeeExempt[receiver] || !feeEnabled) {
            return amount;
        }
        if(lpPairs[receiver]) {            
            totalFee = SellFees.totalFee;         
        } else if(lpPairs[sender]){
            totalFee = BuyFees.totalFee;
        } else {
            totalFee = TransferFees.totalFee;
        }

        uint256 feeAmount = (amount * totalFee) / feeDenominator;

        if (LiquiditySettings.autoLiquifyEnabled) {
            LiquiditySettings.liquidityFeeAccumulator += ((feeAmount * (BuyFees.liquidityFee + SellFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee) + (BuyFees.liquidityFee + SellFees.liquidityFee)));
        }
        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);  
        return amount - feeAmount;
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            !lpPairs[_msgSender()] &&
            !LiquiditySettings.inSwap &&
            LiquiditySettings.swapEnabled &&
            block.timestamp >= LiquiditySettings.lastSwap + LiquiditySettings.swapInterval &&
            _balances[address(this)] >= LiquiditySettings.numTokensToSwap;
    }

    function swapBack() internal swapping {
        LiquiditySettings.lastSwap = block.timestamp;
        if (LiquiditySettings.liquidityFeeAccumulator >= LiquiditySettings.numTokensToSwap && LiquiditySettings.autoLiquifyEnabled) {
            LiquiditySettings.liquidityFeeAccumulator -= LiquiditySettings.numTokensToSwap;
            uint256 amountToLiquify = LiquiditySettings.numTokensToSwap / 2;

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

            uint256 balanceBefore = address(this).balance;

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToLiquify,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountEth = address(this).balance - (balanceBefore);

            router.addLiquidityETH{value: amountEth}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );

            emit AutoLiquify(amountEth, amountToLiquify);
        } else {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

            uint256 balanceBefore = address(this).balance;

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                LiquiditySettings.numTokensToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountEth = address(this).balance - (balanceBefore);

            uint256 amountEthReflection = (amountEth *
                (BuyFees.reflectionFee + SellFees.reflectionFee)) /
                (BuyFees.totalFee + SellFees.totalFee);
            uint256 amountEthTreasury = (amountEth *
                (BuyFees.treasuryFee + SellFees.treasuryFee)) /
                (BuyFees.totalFee + SellFees.totalFee);

            if(fundRewards){
                if(manualDeposit) {
                    try distributor.deposit{value: manualDepositAmount}() {} catch {}
                    (bool success, ) = payable(treasuryFeeReceiver).call{
                    value: amountEthTreasury,
                    gas: 30000}("");
                    if (success) {
                        treasuryFees += amountEthTreasury;
                        manualDeposit = false;
                        manualDepositAmount = 0;
                    }
                } else {
                    try distributor.deposit{value: amountEthReflection}() {} catch {}
                    (bool success, ) = payable(treasuryFeeReceiver).call{
                    value: amountEthTreasury,
                    gas: 30000}("");
                    if (success) { 
                        treasuryFees += amountEthTreasury;
                    }  
                }
            } else {
                payable(treasuryFeeReceiver).transfer(amountEthTreasury);
                treasuryFees += amountEthTreasury;
            }

            emit SwapBack(LiquiditySettings.numTokensToSwap, amountEth);
        }
    }

    function _manualDeposit(uint256 amount, bool fundReward) external authorized {
        require(amount <= address(this).balance);
        manualDeposit = true;
        fundRewards = fundReward;
        manualDepositAmount = amount;
    }

    function launch(uint8 sniperBlocks) public onlyOwner {
        require(sniperBlocks <= 5);
        require(!tradingOpen);
        LiquiditySettings.autoLiquifyEnabled = true;        
        setTransactionLimits(true);
        setSwapBackSettings(true, 10);
        setCooldownEnabled(true, true, 30);
        autoClaimEnabled = true;   
        setSellFees(2, 4, 8);
        setBuyFees(2, 4, 8);
        setTransferFees(1, 1, 2);
        setTxLimit(1,100);
        setMaxWallet(2,100);
        fundRewards = true;
        feeEnabled = true;
        if(!Launch.launched) {
            Launch.launched = true;
            Launch.antiBlocks = sniperBlocks;
            Launch.launchBlock = block.number; 
            Launch.launchProtection = true;
        }        
        tradingOpen = true;
        emit Launched();
    }

    function setTransactionLimits(bool enabled) public onlyOwner {
        TransactionSettings.txLimits = enabled;
    }

    function setTxLimit(uint256 percent, uint256 divisor) public authorized {
        require(percent >= 1 && divisor <= 1000);
        TransactionSettings.maxTxAmount = (_totalSupply * (percent)) / (divisor);
        emit TxLimitUpdated(TransactionSettings.maxTxAmount);
    }

    function setMaxWallet(uint256 percent, uint256 divisor) public authorized {
        require(percent >= 1 && divisor <= 1000);
        TransactionSettings.maxWalletAmount = (_totalSupply * percent) / divisor;
        emit WalletLimitUpdated(TransactionSettings.maxWalletAmount);
    }

    function setIsDividendExempt(address holder, bool exempt) external authorized{
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if (exempt) {
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, _balances[holder]);
        }
        emit DividendExemptUpdated(holder, exempt);
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
        emit FeeExemptUpdated(holder, exempt);
    }

    function turnOff() internal {
        Launch.launchProtection = false;
    }

    function _setBlacklistStatus(address account, bool blacklisted) internal {
        if(!lpPairs[account] || account != address(this) || account != address(router) || !isFeeExempt[account]) {
            if (blacklisted == true) {
                bannedUsers[account] = true;
            } else {
                bannedUsers[account] = false;
            }         
        }  
    }
    
    function setWalletBanStatus(address[] memory user, bool banned) external onlyOwner {
        for(uint256 i; i < user.length; i++) {
            _setBlacklistStatus(user[i], banned);
            emit WalletBanStatusUpdated(user[i], banned);
        }
    }

    function setMaxWalletExempt(address holder, bool exempt) external authorized {
        maxWalletExempt[holder] = exempt;
        emit TxLimitExemptUpdated(holder, exempt);
    }

    function setBuyFees(uint16 _liquidityFee, uint16 _reflectionFee, uint16 _treasuryFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _treasuryFee <= MaxFees.treasuryFee);
        BuyFees = IFees({
            liquidityFee: _liquidityFee,
            reflectionFee: _reflectionFee,
            treasuryFee: _treasuryFee,
            totalFee: _liquidityFee + _reflectionFee + _treasuryFee
        });
    }
    
    function setTransferFees(uint16 _liquidityFee, uint16 _reflectionFee, uint16 _treasuryFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _treasuryFee <= MaxFees.treasuryFee);
        TransferFees = IFees({
            liquidityFee: _liquidityFee,
            reflectionFee: _reflectionFee,
            treasuryFee: _treasuryFee,
            totalFee: _liquidityFee + _reflectionFee + _treasuryFee
        });
    }

    function setSellFees(uint16 _liquidityFee, uint16 _reflectionFee, uint16 _treasuryFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _treasuryFee <= MaxFees.treasuryFee);
        SellFees = IFees({
            liquidityFee: _liquidityFee,
            reflectionFee: _reflectionFee,
            treasuryFee: _treasuryFee,
            totalFee: _liquidityFee + _reflectionFee + _treasuryFee
        });
    } 

    function setMaxFees(uint16 _liquidityFee, uint16 _reflectionFee, uint16 _treasuryFee, bool resetFees) public onlyOwner {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _treasuryFee <= MaxFees.treasuryFee);
        MaxFees = IFees({
            liquidityFee: _liquidityFee,
            reflectionFee: _reflectionFee,
            treasuryFee: _treasuryFee,
            totalFee: _liquidityFee + _reflectionFee + _treasuryFee
        });
        if(resetFees){
            setBuyFees(_liquidityFee, _reflectionFee, _treasuryFee);
            setSellFees(_liquidityFee, _reflectionFee, _treasuryFee);
        }
    }

    function FeesEnabled(bool _enabled) external onlyOwner {
        feeEnabled = _enabled;
        emit areFeesEnabled(_enabled);
    }

    function setFeeReceivers(address _autoLiquidityReceiver, address _treasuryFeeReceiver) public onlyOwner {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        treasuryFeeReceiver = _treasuryFeeReceiver;
        emit FeeReceiversUpdated(_autoLiquidityReceiver, _treasuryFeeReceiver);
    }

    function setCooldownEnabled(bool buy, bool sell, uint8 _cooldown) public authorized {
        require(_cooldown <= cooldownInfo.cooldownLimit);
        cooldownInfo.cooldownTime = _cooldown;
        cooldownInfo.buycooldownEnabled = buy;
        cooldownInfo.sellcooldownEnabled = sell;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) public authorized{
        LiquiditySettings.swapEnabled = _enabled;
        LiquiditySettings.numTokensToSwap = (_totalSupply * (_amount)) / (10000);
        emit SwapBackSettingsUpdated(_enabled, _amount);
    }

   function setAutoLiquifyEnabled(bool _enabled) public authorized {
        LiquiditySettings.autoLiquifyEnabled = _enabled;
        emit AutoLiquifyUpdated(_enabled);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldReq) external authorized {
        distributor.setDistributionCriteria(
            _minPeriod,
            _minDistribution,
            _minHoldReq
        );
    }

    function setDistributorSettings(uint32 gas, bool _autoClaim) external authorized {
        require(gas <= 1000000);
        distributorGas = gas;
        autoClaimEnabled = _autoClaim;
        emit DistributorSettingsUpdated(gas, _autoClaim);
    }

    function getAccumulatedFees() external view returns (uint256) {
        return treasuryFees;
    }

    function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return distributor.getShareholderInfo(shareholder);
    }

    function getAccountInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return distributor.getAccountInfo(shareholder);
    }

    function holdReq() public view returns(uint256) {
        return distributor.holdReq();
    }

    function claimDividendFor(address shareholder) public {
        distributor.claimDividendFor(shareholder);
    }

    function claimDividend() public {
        distributor.claimDividendFor(msg.sender);
    }

    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
        emit Authorized(adr);
    }

    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
        emit Unauthorized(adr);
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        require(amountPercentage <= 100);
        uint256 amountEth = address(this).balance;
        payable(treasuryFeeReceiver).transfer(
            (amountEth * amountPercentage) / 100
        );
    }

    function clearStuckToken(address to) external onlyOwner {
        uint256 _balance = balanceOf(address(this));
        _basicTransfer(address(this), to, _balance);
    }

    function clearStuckTokens(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0));
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }

    function airDropTokens(address[] memory addresses, uint256[] memory amounts) external onlyOwner{
        require(addresses.length == amounts.length, "Lengths do not match.");
        for (uint8 i = 0; i < addresses.length; i++) {
            require(balanceOf(msg.sender) >= amounts[i]);
            _basicTransfer(msg.sender, addresses[i], amounts[i]*10**_decimals);
        }
    }

    event WalletLimitUpdated(uint256 amount);
    event OwnershipTransferred(address owner);
    event Authorized(address adr);
    event Unauthorized(address adr);
    event Launched();
    event AutoLiquify(uint256 amountEth, uint256 amountToken);
    event SwapBack(uint256 amountToken, uint256 amountEth);
    event TxLimitUpdated(uint256 amount);
    event DividendExemptUpdated(address holder, bool exempt);
    event FeeExemptUpdated(address holder, bool exempt);
    event TxLimitExemptUpdated(address holder, bool exempt);
    event FeeReceiversUpdated(address autoLiquidityReceiver, address treasuryFeeReceiver);
    event SwapBackSettingsUpdated(bool enabled, uint256 amount);
    event areFeesEnabled(bool _enabled);
    event AutoLiquifyUpdated(bool enabled);
    event DistributorSettingsUpdated(uint256 gas, bool autoClaim);
    event WalletBanStatusUpdated(address user, bool banned);
}
