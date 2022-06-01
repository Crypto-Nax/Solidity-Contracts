// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

interface IFactory {
    event PairCreated(address indexed token0, address indexed token1, address liquidityPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address liquidityPair);
    function createPair(address tokenA, address tokenB) external returns (address liquidityPair);
}

interface IPair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);

    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(
        uint112 reserve0,
        uint112 reserve1
    );

}

interface IRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

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
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
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

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
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

contract DividendDistributor is IDividendDistributor, AccessControl {
    using SafeMath for uint256;
    
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    IRouter02 router;
    
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

    constructor (address _router) {
        _setRoleAdmin(TOKEN_ROLE, TOKEN_ROLE);
        _setupRole(TOKEN_ROLE, msg.sender);
        router = IRouter02(_router);
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

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldReq) external override onlyRole(TOKEN_ROLE) {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
        minHoldReq = _minHoldReq * (10**9);
        emit DistributionCriteriaUpdated(minPeriod, minDistribution, minHoldReq);
    }
    
    function setShare(address shareholder, uint256 amount) external override onlyRole(TOKEN_ROLE) {
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
    
    function deposit() external payable override onlyRole(TOKEN_ROLE) {

        uint256 amount = msg.value;
    
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
            
        emit Deposit(amount);
    }
    
    function process(uint256 gas) external override onlyRole(TOKEN_ROLE) {
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

contract RewardToken is Pausable, AccessControl, ERC20Permit {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint16 _totalFee;
    mapping(address => bool) _cooldownExempt;
    mapping(address => bool) public _isBlacklisted;    
    mapping(address => bool) public _isDividendExempt;
    mapping(address => bool) _isFeeExempt;
    mapping(address => bool) _isLiquidityPair;
    mapping(address => bool) _isLiquidityHolder;
    mapping(address => bool) _isMaxWalletExempt;
    mapping(address => bool) _isTransactionLimitExempt;
    mapping(address => bool) _isPreTrader;
    mapping(address => bool) _routers;
    mapping(address => uint) _timeTillCooldown;

    struct IContract {
        uint16 feeDivisor;
        uint256 distributorGas;     
        uint256 manualDepositAmount;  
        bool burnFees; 
        bool burnBuyback;
        bool autoClaimEnabled; 
        bool feesEnabled;
        bool fundRewards;
        bool manualDeposit;
        bool earlySellFees;
    }
    struct IFees {
        uint16 reflectionFee;
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 buyBackFee;
        uint16 totalFee;
    }
    struct ILaunch {
        uint256 launchedAt;
        uint256 launchBlock;
        uint256 antiBlocks;
        bool launched;
        bool launchProtection;
    }
    struct ICooldown {
        bool buycooldownEnabled;
        bool sellcooldownEnabled;
        uint256 cooldownLimit;
        uint256 cooldownTime;
    }
    struct ILiquiditySettings {
        uint256 liquidityFeeAccumulator;
        uint256 numTokensToSwap;
        uint256 lastSwap;
        uint8 swapInterval;
        bool swapEnabled;
        bool autoLiquifyEnabled;
        bool inSwap;
    }
    struct ITransactionSettings {
        uint256 maxTransactionAmount;
        uint256 maxWalletAmount;
        bool txLimits;
    }
    struct IBuyBackSettings{
        bool autoBuybackEnabled;
        uint256 autoBuybackCap;
        uint256 autoBuybackAccumulator;
        uint256 autoBuybackAmount;
        uint256 autoBuybackBlockPeriod;
        uint256 autoBuybackBlockLast;
    }
    IFees public MaxFees;
    IFees public BuyFees;
    IFees public SellFees;
    IFees public TransferFees;
    ICooldown public CooldownInfo;
    IContract public ContractSettings;
    ILaunch public Launch;
    ILiquiditySettings public LiquiditySettings;
    ITransactionSettings public TransactionSettings;
    IBuyBackSettings public BuyBackSettings;
    IRouter02 immutable public _initialRouter;        
    DividendDistributor public _distributor;
    address immutable public _initialPair;
    address _marketingFeeReceiver;
    address _autoLiquidityReceiver;
    address _buyBackReceiver;

    modifier swapping() {
        LiquiditySettings.inSwap = true;
        _;
        LiquiditySettings.inSwap = false;
    }

    constructor(uint256 initialSupply, string memory name, string memory symbol, address initialRouter) ERC20(name, symbol) ERC20Permit(name){
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(ADMIN_ROLE, msg.sender);        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        address thisCa = address(this);
        _distributor = new DividendDistributor(initialRouter);

        IRouter02 router = IRouter02(initialRouter);
        _initialRouter = router;             
        address pair = IFactory(router.factory()).createPair(thisCa, router.WETH());
        _initialPair = pair;
        
        _isLiquidityPair[pair] = true;
        _routers[initialRouter] = true;
        _isLiquidityHolder[_msgSender()] = true;

        _cooldownExempt[initialRouter] = true;
        _cooldownExempt[thisCa] = true;
        _cooldownExempt[_msgSender()] = true;

        _isMaxWalletExempt[thisCa] = true;
        _isMaxWalletExempt[pair] = true;
        _isMaxWalletExempt[_msgSender()] = true;
        _isMaxWalletExempt[address(0xdead)] = true;

        _isTransactionLimitExempt[thisCa] = true;
        _isTransactionLimitExempt[_msgSender()] = true;

        _isFeeExempt[thisCa] = true;
        _isFeeExempt[_msgSender()] = true;

        _isPreTrader[_msgSender()] = true;

        _autoLiquidityReceiver = _msgSender();
        _marketingFeeReceiver = _msgSender();
        _buyBackReceiver = _msgSender();

        _isDividendExempt[thisCa] = true;
        _isDividendExempt[pair] = true;
        _isDividendExempt[address(0xdead)] = true;

        _approve(_msgSender(), address(initialRouter), type(uint256).max);
        _approve(thisCa, address(initialRouter), type(uint256).max);

        CooldownInfo.cooldownLimit = 60;
        ContractSettings.feeDivisor = 10000;

        _mint(_msgSender(), initialSupply * 10 ** decimals());
    }
    //To receive Ether from routers
    receive() external payable {}

    function limits(address from, address to) private view returns (bool) {
        return !hasRole(ADMIN_ROLE, from)
            && !hasRole(ADMIN_ROLE, to)
            && !hasRole(ADMIN_ROLE, tx.origin)
            && !_isLiquidityHolder[from]
            && !_isLiquidityHolder[to]
            && to != address(0xdead)
            && to != address(0)
            && from != address(this);
    }

    // Set Pair Or Router Function
    function setRouterOrPair(address addr, uint8 routerOrPair, bool setOrRemove) public onlyRole(ADMIN_ROLE) {
        require(routerOrPair == 0 || routerOrPair == 1);
        if(routerOrPair == 0){
            _routers[addr] = setOrRemove;
        } else {
            _isLiquidityPair[addr] = setOrRemove;
        }
    }

    // Set Liquidity Holder Function
    function setLiquidityHolder(address holder, bool setOrRemove) public onlyRole(ADMIN_ROLE) {
        _isLiquidityHolder[holder] = setOrRemove;
    }

    // Pause Or Unpause Trading
    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Allow Address For PreTrading
    function allowPreTrading(address account, bool allowed) public onlyRole(ADMIN_ROLE) {
        require(_isPreTrader[account] != allowed, "TOKEN: Already enabled.");
        _isPreTrader[account] = allowed;
    }

    // Set Marketing And Liquidity Fee And BuyBack Receiver Function

    function setFeeReceiver(address lReceiver, address bReceiver, address mReceiver) public onlyRole(ADMIN_ROLE) {
        _autoLiquidityReceiver = lReceiver;
        _marketingFeeReceiver = mReceiver;
        _buyBackReceiver = bReceiver;
    }

    // Blacklist and Launch protection functions
    function turnOff() private {
        Launch.launchProtection = false;
    }

    function checkBlacklist(address account) internal view returns(bool) {
        return !_isLiquidityPair[account]
        && account != address(this)
        && !_routers[account]
        && !_isFeeExempt[account];
    }

    function _setBlacklistStatus(address account) internal {
        if(checkBlacklist(account)) {
            _isBlacklisted[account] = true;
        }  
    }

    function _setBlacklistStatus(address[] memory account, bool blacklisted) public onlyRole(ADMIN_ROLE) {
        for(uint i; i < account.length; i++){
            if(checkBlacklist(account[i])) {
                _isBlacklisted[account[i]] = blacklisted;
            }
        }
    }

    // Transfer Function
    function airDropTokens(address[] memory addresses, uint256[] memory amounts) external onlyRole(ADMIN_ROLE){
        require(addresses.length == amounts.length, "Lengths do not match.");
        for (uint8 i = 0; i < addresses.length; i++) {
            require(balanceOf(_msgSender()) >= amounts[i]);
            ERC20.transfer(addresses[i], amounts[i]*10**decimals());
        }
    }

    function preTransferCheck(address from, address to, uint amount) private view returns(bool){       
        require(!_isBlacklisted[from], "TOKEN: Your account is blacklisted!");
        require(!_isBlacklisted[to], "TOKEN: Your account is blacklisted!");
        require(amount > 0, "ERC20: Transfer amount must be greater than zero");
        return true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }


    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused() {
        require(preTransferCheck(from, to, amount));
        uint256 amountReceived = amount;
        if(limits(from, to)){
            if(!Launch.launched){
                require(checkLaunched(from));
            }
            if(Launch.launched){
                if(checkTransaction(from, to)){require(checkTransactionLimit(amount));}
                if(checkWallet(to)){require(checkWalletLimit(to, amount));}                    
                checkCooldown(from) ? require(setCooldown(from, to, true)) : require(setCooldown(from, to, false)); 
                if(Launch.launchProtection) {
                    if(Launch.launchBlock + Launch.antiBlocks <= block.number) {
                        turnOff();
                    }
                    if (block.number  <= Launch.launchBlock + Launch.antiBlocks) {
                        _setBlacklistStatus(to);
                    }
                }
                if(shouldSwapBack()){swapBack();}
                if(shouldAutoBuyback()){triggerAutoBuyback();}
                amountReceived = ContractSettings.feesEnabled && !_isFeeExempt[from] ? takeFee(from, to, amount) : amount;
            }
        }
        ERC20._transfer(from, to, amountReceived);
        checkDividend(from, to);
    }

    function checkDividend(address from, address to) internal {
        if (!_isDividendExempt[from] && balanceOf(from) >= _distributor.holdReq()) { try _distributor.setShare(from, balanceOf(from)) {} catch {} }
        if (!_isDividendExempt[to] && balanceOf(to) >= _distributor.holdReq()) { try _distributor.setShare(to, balanceOf(to)) {} catch {} }
        if(ContractSettings.autoClaimEnabled) { try _distributor.process( ContractSettings.distributorGas) {} catch {} }
    }

    // One Way Switch to Launch Token
    function launch(uint8 sniperBlocks) public onlyRole(ADMIN_ROLE) {
        require(sniperBlocks <= 5);
        require(!Launch.launched);
        setTransactionLimits(true);
        setSwapBackSettings(true, 10, true);
        setCooldownEnabled(true, true, 30);
        ContractSettings.autoClaimEnabled = true;
        setMaxFees(400,400,400,400);
        setBuyFees(200,200,200,200);
        SellFees = IFees({
            liquidityFee: 300,
            reflectionFee: 500,
            marketingFee: 700,
            buyBackFee: 500,
            totalFee: 300 + 500 + 700 + 500
        });        
        setTransferFees(200, 100, 100, 200);
        setMaxTransactionAmount(1,100);
        setMaxWalletAmount(2,100);
        ContractSettings.fundRewards = true;
        ContractSettings.feesEnabled = true;
        ContractSettings.earlySellFees = true;
        Launch.launched = true;
        Launch.antiBlocks = sniperBlocks;
        Launch.launchedAt = block.timestamp;
        Launch.launchBlock = block.number; 
        Launch.launchProtection = true;  
    }

    // Functions for Contract swap
    function setSwapBackSettings(bool _enabled, uint256 _amount, bool _liquify) public onlyRole(ADMIN_ROLE){
        LiquiditySettings.swapEnabled = _enabled;
        LiquiditySettings.numTokensToSwap = (totalSupply() * (_amount)) / (10000);
        LiquiditySettings.autoLiquifyEnabled = _liquify;
    }

    function shouldSwapBack() internal view returns (bool) {
        return !LiquiditySettings.inSwap &&
            !_isLiquidityPair[_msgSender()] &&
            LiquiditySettings.swapEnabled &&
            block.timestamp >= LiquiditySettings.lastSwap + LiquiditySettings.swapInterval &&
            balanceOf(address(this)) >= LiquiditySettings.numTokensToSwap;
    }

    function swapTokensForEth(uint256 amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _initialRouter.WETH();

        _initialRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 amount, uint256 amountEth) internal {
        _approve(address(this), address(_initialRouter), type(uint256).max);
        _initialRouter.addLiquidityETH{value: amountEth}(
                address(this),
                amount,
                0,
                0,
                _autoLiquidityReceiver,
                block.timestamp
            );
    }

    function swapBack() internal swapping() {
        LiquiditySettings.lastSwap = block.timestamp;
        if (LiquiditySettings.liquidityFeeAccumulator >= LiquiditySettings.numTokensToSwap && LiquiditySettings.autoLiquifyEnabled) {
            LiquiditySettings.liquidityFeeAccumulator -= LiquiditySettings.numTokensToSwap;
            uint256 amountToLiquify = LiquiditySettings.numTokensToSwap / 2;
            uint256 balanceBefore = address(this).balance;

            swapTokensForEth(amountToLiquify);
            uint256 amountEth = address(this).balance - (balanceBefore);

            addLiquidity(amountToLiquify, amountEth);

        } else {
            uint256 balanceBefore = address(this).balance;

            swapTokensForEth(LiquiditySettings.numTokensToSwap);

            uint256 amountEth = address(this).balance - (balanceBefore);

            uint256 amountEthReflection = (amountEth * (BuyFees.reflectionFee + SellFees.reflectionFee)) / (BuyFees.totalFee + SellFees.totalFee);
            uint256 amountEthMarketing = (amountEth * (BuyFees.marketingFee + SellFees.marketingFee)) / (BuyFees.totalFee + SellFees.totalFee);

            if(ContractSettings.fundRewards){
                if(ContractSettings.manualDeposit){
                    try _distributor.deposit{value: ContractSettings.manualDepositAmount } () {} catch {}
                    ContractSettings.manualDepositAmount = 0;
                    ContractSettings.manualDeposit = false;
                    payable(_marketingFeeReceiver).call{value: amountEthMarketing, gas: 30000};
                } else {
                    try _distributor.deposit{value:amountEthReflection}() {} catch {}
                    payable(_marketingFeeReceiver).call{value: amountEthMarketing, gas: 30000};
                }
            } else {      
                payable(_marketingFeeReceiver).call{value: amountEthMarketing, gas:30000};
            }


        }
    }
    
    function _manualDeposit(uint256 amount, bool fundReward) external onlyRole(ADMIN_ROLE) {
        require(amount <= address(this).balance);
        ContractSettings.manualDeposit = true;
        ContractSettings.fundRewards = fundReward;
        ContractSettings.manualDepositAmount = amount;
    }

    // Functions for Buybacks
    function shouldAutoBuyback() internal view returns (bool) {
        return !_isLiquidityPair[_msgSender()]
        && !LiquiditySettings.inSwap
        && BuyBackSettings.autoBuybackEnabled
        && BuyBackSettings.autoBuybackBlockLast + BuyBackSettings.autoBuybackBlockPeriod <= block.number
        && address(this).balance >= BuyBackSettings.autoBuybackAmount;
    }
    
    function buybackWEI(uint256 amount) external onlyRole(ADMIN_ROLE) {
        buyTokens(amount, _buyBackReceiver);
    }
    
    function triggerAutoBuyback() internal {
        buyTokens(BuyBackSettings.autoBuybackAmount, _buyBackReceiver);
        BuyBackSettings.autoBuybackBlockLast = block.number;
        BuyBackSettings.autoBuybackAccumulator = BuyBackSettings.autoBuybackAccumulator.add(BuyBackSettings.autoBuybackAmount);
        if(BuyBackSettings.autoBuybackAccumulator > BuyBackSettings.autoBuybackCap){ BuyBackSettings.autoBuybackEnabled = false; }
    }
    
    function swapForTokens(uint256 amount, address to) internal swapping() {
        address[] memory path = new address[](2);
        path[0] = _initialRouter.WETH();
        path[1] = address(this);

        _initialRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            to,
            block.timestamp
        );
    }

    function buyTokens(uint256 amount, address to) internal {
        if(ContractSettings.burnBuyback){
            uint256 beforeBuyback = balanceOf(address(this));
            swapForTokens(amount, address(this));
            uint256 afterBuyback = balanceOf(address(this)) - beforeBuyback;
            _burn(address(this), afterBuyback);
        } else {
            swapForTokens(amount, to);
        }
    }
    
    function setAutoBuybackSettings(bool _enabled, uint256 _cap, uint256 _amount, uint256 _period) external onlyRole(ADMIN_ROLE) {
        BuyBackSettings.autoBuybackEnabled = _enabled;
        BuyBackSettings.autoBuybackCap = _cap;
        BuyBackSettings.autoBuybackAccumulator = 0;
        BuyBackSettings.autoBuybackAmount = _amount;
        BuyBackSettings.autoBuybackBlockPeriod = _period;
        BuyBackSettings.autoBuybackBlockLast = block.number;
    }

    // Function to check and set cooldown
    function checkCooldown(address from) internal view returns (bool buyOrSell) {
        if(_isLiquidityPair[from] && CooldownInfo.buycooldownEnabled){
            buyOrSell = true;
            return buyOrSell;
        } else if(!_isLiquidityPair[from] && CooldownInfo.sellcooldownEnabled) {
            buyOrSell = false;
            return buyOrSell;
        }
    }

    function setCooldown(address from, address to, bool buy) internal returns(bool){
        if(buy) {
            if(!_cooldownExempt[to]){
            require(_timeTillCooldown[to] < block.timestamp, "Token: Cooldown in place");
            _timeTillCooldown[to] = block.timestamp + CooldownInfo.cooldownTime;
            }
        } else {
            if(!_cooldownExempt[from]){
            require(_timeTillCooldown[from] < block.timestamp, "Token: Cooldown in place");
            _timeTillCooldown[from] = block.timestamp + CooldownInfo.cooldownTime;
            }
        }
        return true;
    }

    function setCooldownEnabled(bool onoff, bool offon, uint8 time) public onlyRole(ADMIN_ROLE) {
        require(time <= CooldownInfo.cooldownLimit);
        CooldownInfo.cooldownTime = time;
        CooldownInfo.buycooldownEnabled = onoff;
        CooldownInfo.sellcooldownEnabled = offon;
    }

    function setCooldownExempt(address holder, bool onOff) public onlyRole(ADMIN_ROLE) {
        _cooldownExempt[holder] = onOff;
    }

    // Function for PreTrading
    function checkLaunched(address sender) internal view returns(bool){
        require(_isPreTrader[sender], "Pre-Launch Protection");
        return true;
    }

    // Function For Transaction and Wallet limits
    function setMaxWalletExempt(address holder, bool setOrRemove) public onlyRole(ADMIN_ROLE){
        _isMaxWalletExempt[holder] = setOrRemove;
    }

    function setTransactionLimitExempt(address holder, bool setOrRemove) public onlyRole(ADMIN_ROLE){
        _isTransactionLimitExempt[holder] = setOrRemove;
    }

    function checkTransaction(address from, address to) internal view returns (bool){
        return TransactionSettings.txLimits 
        && !_isTransactionLimitExempt[to]
        && !_isTransactionLimitExempt[from];
    }
    
    function checkTransactionLimit(uint256 amount) internal view returns(bool){
        require(amount <= TransactionSettings.maxTransactionAmount, "TOKEN: Amount exceeds Transaction size");
        return true;
    }

    function setMaxTransactionAmount(uint16 percent, uint16 divisor) public onlyRole(ADMIN_ROLE) {
        require((totalSupply() * percent) / divisor >= totalSupply() / 1000, "Max Transaction Amount must be above 0.1% of the total supply");

        TransactionSettings.maxTransactionAmount = (totalSupply() * percent) / divisor;
    }

    function setMaxWalletAmount(uint16 percent, uint16 divisor) public onlyRole(ADMIN_ROLE) {
        require((totalSupply() * percent) / divisor >= totalSupply() / 1000, "Max Wallet Amount must be above 0.1% of the total supply");
        TransactionSettings.maxWalletAmount = (totalSupply() * percent) / divisor;
    }

    function setTransactionLimits(bool limited) public onlyRole(ADMIN_ROLE) {
        TransactionSettings.txLimits = limited;
    }

    function checkWallet(address to) internal view returns (bool){
        return TransactionSettings.txLimits 
        && !_isMaxWalletExempt[to];
    }

    function checkWalletLimit(address to, uint256 amount) internal view returns (bool) {
        require(balanceOf(to) + amount <= TransactionSettings.maxWalletAmount, "TOKEN: Amount exceeds Wallet size");
        return true;
    }    

    // Dividend Functions
    function setIsDividendExempt(address holder, bool exempt) public onlyRole(ADMIN_ROLE){
        require(holder != address(this) && !_isLiquidityPair[holder]);
            _isDividendExempt[holder] = exempt;
        if (exempt) {
            _distributor.setShare(holder, 0);
        } else {
            _distributor.setShare(holder, balanceOf(holder));
        }
    }

    function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return _distributor.getShareholderInfo(shareholder);
    }

    function getAccountInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return _distributor.getAccountInfo(shareholder);
    }

    function claimDividendFor(address shareholder) public {
        _distributor.claimDividendFor(shareholder);
    }

    function claimDividend() public {
        _distributor.claimDividendFor(msg.sender);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldReq) external onlyRole(ADMIN_ROLE) {
        _distributor.setDistributionCriteria(
            _minPeriod,
            _minDistribution,
            _minHoldReq
        );
    }

    function setDistributorSettings(uint32 gas, bool _autoClaim) external onlyRole(ADMIN_ROLE) {
        require(gas <= 1000000);
        ContractSettings.distributorGas = gas;
        ContractSettings.autoClaimEnabled = _autoClaim;
    }
    // Functions to set fees and Exempt Or Include Holder From Fees
    function setFeeExempt(address holder, bool setOrRemove) public onlyRole(ADMIN_ROLE) {
        _isFeeExempt[holder] = setOrRemove;
    }

    function enableFees(bool _feeEnabled) public onlyRole(ADMIN_ROLE) {
        ContractSettings.feesEnabled = _feeEnabled;
    }

    function setBuyFees(uint16 liquidityFee, uint16 reflectionFee, uint16 marketingFee, uint16 buybackFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && reflectionFee <= MaxFees.reflectionFee && marketingFee <= MaxFees.marketingFee && buybackFee <= MaxFees.buyBackFee, "Fee Higher than Max Fees");
        BuyFees = IFees({
            liquidityFee: liquidityFee,
            reflectionFee: reflectionFee,
            marketingFee: marketingFee,
            buyBackFee: buybackFee,
            totalFee: liquidityFee + reflectionFee + marketingFee + buybackFee
        });
    }    
    
    function setSellFees(uint16 liquidityFee, uint16 reflectionFee, uint16 marketingFee, uint16 buybackFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && reflectionFee <= MaxFees.reflectionFee && marketingFee <= MaxFees.marketingFee && buybackFee <= MaxFees.buyBackFee, "Fee Higher than Max Fees");
        SellFees = IFees({
            liquidityFee: liquidityFee,
            reflectionFee: reflectionFee,
            marketingFee: marketingFee,
            buyBackFee: buybackFee,
            totalFee: liquidityFee + reflectionFee + marketingFee + buybackFee
        });

    }    
    
    function setTransferFees(uint16 liquidityFee, uint16 reflectionFee, uint16 marketingFee, uint16 buybackFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && reflectionFee <= MaxFees.reflectionFee && marketingFee <= MaxFees.marketingFee && buybackFee <= MaxFees.buyBackFee, "Fee Higher than Max Fees");
        TransferFees = IFees({
            liquidityFee: liquidityFee,
            reflectionFee: reflectionFee,
            marketingFee: marketingFee,
            buyBackFee: buybackFee,
            totalFee: liquidityFee + reflectionFee + marketingFee + buybackFee
        });
    }    
    
    function setMaxFees(uint16 liquidityFee, uint16 reflectionFee, uint16 marketingFee, uint16 buybackFee) public onlyRole(ADMIN_ROLE) {
        if(!Launch.launched){
            MaxFees = IFees({
                liquidityFee: liquidityFee,
                reflectionFee: reflectionFee,
                marketingFee: marketingFee,
                buyBackFee: buybackFee,
                totalFee: liquidityFee + reflectionFee + marketingFee + buybackFee
            });                
        } else {
            require(liquidityFee <= MaxFees.liquidityFee && reflectionFee <= MaxFees.reflectionFee && marketingFee <= MaxFees.marketingFee && buybackFee <= MaxFees.buyBackFee, "Fee Higher than Max Fees");
            MaxFees = IFees({
                liquidityFee: liquidityFee,
                reflectionFee: reflectionFee,
                marketingFee: marketingFee,
                buyBackFee: buybackFee,
                totalFee: liquidityFee + reflectionFee + marketingFee + buybackFee
            });
        }
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        if (block.timestamp >= Launch.launchedAt + 24 hours && ContractSettings.earlySellFees){
            setSellFees(200, 200, 200, 200);
            ContractSettings.earlySellFees = false;
        }
        if (_isFeeExempt[receiver]) {
            return amount;
        }
        if(_isLiquidityPair[receiver]) {            
            _totalFee = SellFees.totalFee;         
        } else if(_isLiquidityPair[sender]){
            _totalFee = BuyFees.totalFee;
        } else {
            _totalFee = TransferFees.totalFee;
        }

        uint256 feeAmount = (amount * _totalFee) / ContractSettings.feeDivisor;

        if (LiquiditySettings.autoLiquifyEnabled) {
            LiquiditySettings.liquidityFeeAccumulator += ((feeAmount * (BuyFees.liquidityFee + SellFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee) + (BuyFees.liquidityFee + SellFees.liquidityFee)));
        }
        if(ContractSettings.burnFees){
            _burn(sender, feeAmount);
        } else {
            ERC20._transfer(sender, address(this), feeAmount);
        }
        return amount - feeAmount;
    }
}
