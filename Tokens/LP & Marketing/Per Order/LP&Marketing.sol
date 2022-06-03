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

contract Token is Pausable, AccessControl, ERC20Permit {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint16 _totalFee;
    mapping(address => bool) _cooldownExempt;
    mapping(address => bool) public _isBlacklisted;    
    mapping(address => bool) _isFeeExempt;
    mapping(address => bool) _isLiquidityPair;
    mapping(address => bool) _isLiquidityHolder;
    mapping(address => bool) _isMaxWalletExempt;
    mapping(address => bool) _isTransactionLimitExempt;
    mapping(address => bool) _isPreTrader;
    mapping(address => bool) _routers;
    mapping(address => uint) _timeTillCooldown;

    bool public earlySellFees;
    bool public burnFees;
    bool public feesEnabled;
    uint16 public feeDivisor;

    struct IFees {
        uint16 liquidityFee;
        uint16 marketingFee;
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
    IFees public MaxFees;
    IFees public BuyFees;
    IFees public SellFees;
    IFees public TransferFees;
    ICooldown public CooldownInfo;
    ILaunch public Launch;
    ILiquiditySettings public LiquiditySettings;
    ITransactionSettings public TransactionSettings;
    IRouter02 immutable public _initialRouter;        
    address immutable public _initialPair;
    address _marketingFeeReceiver;
    address _autoLiquidityReceiver;

    modifier swapping() {
        LiquiditySettings.inSwap = true;
        _;
        LiquiditySettings.inSwap = false;
    }

    constructor(uint256 initialSupply, string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name){
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(ADMIN_ROLE, msg.sender);        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        address thisCa = address(this);

        IRouter02 router = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _initialRouter = router;             
        address pair = IFactory(router.factory()).createPair(thisCa, router.WETH());
        _initialPair = pair;
        
        _isLiquidityPair[pair] = true;
        _routers[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;
        _isLiquidityHolder[_msgSender()] = true;

        _cooldownExempt[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;
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

        _approve(_msgSender(), address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), type(uint256).max);
        _approve(thisCa, address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), type(uint256).max);

        CooldownInfo.cooldownLimit = 60;
        feeDivisor = 10000;

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

    // Set Marketing And Liquidity Fee Receiver Function
    function setFeeReceiver(address lReceiver, address mReceiver) public onlyRole(ADMIN_ROLE) {
        _autoLiquidityReceiver = lReceiver;
        _marketingFeeReceiver = mReceiver;
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
                if(_isLiquidityPair[from] && CooldownInfo.buycooldownEnabled){require(setCooldown(to));}                 
                if(Launch.launchProtection) {
                    if(Launch.launchBlock + Launch.antiBlocks <= block.number) {turnOff();}
                    if (block.number  <= Launch.launchBlock + Launch.antiBlocks) {_setBlacklistStatus(to);}
                }
                if(shouldSwapBack()){swapBack();}
                amountReceived = feesEnabled && !_isFeeExempt[from] ? takeFee(from, to, amount) : amount;
            }
        }
        ERC20._transfer(from, to, amountReceived);
    }

    // One Way Switch to Launch Token
    function launch(uint8 sniperBlocks) public onlyRole(ADMIN_ROLE) {
        require(sniperBlocks <= 5);
        require(!Launch.launched);
        setTransactionLimits(true);
        setSwapBackSettings(true, 10, true);
        setCooldownEnabled(true, 30);
        setMaxFees(500,2000);
        setBuyFees(0,0);
        setSellFees(200,1800);
        setTransferFees(0, 500);
        setMaxTransactionAmount(1,100);
        setMaxWalletAmount(2,100);
        feesEnabled = true;
        earlySellFees = true;
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
            swapTokensForEth(LiquiditySettings.numTokensToSwap);
            payable(_marketingFeeReceiver).transfer(address(this).balance);
        }
    }

    function setCooldown(address to) internal returns(bool){
        if(!_cooldownExempt[to]){
            require(_timeTillCooldown[to] < block.timestamp, "Token: Cooldown in place");
            _timeTillCooldown[to] = block.timestamp + CooldownInfo.cooldownTime;
        }
        return true;
    }

    function setCooldownEnabled(bool onoff, uint8 time) public onlyRole(ADMIN_ROLE) {
        require(time <= CooldownInfo.cooldownLimit);
        CooldownInfo.cooldownTime = time;
        CooldownInfo.buycooldownEnabled = onoff;
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

    // Functions to set fees and Exempt Or Include Holder From Fees
    function setFeeExempt(address holder, bool setOrRemove) public onlyRole(ADMIN_ROLE) {
        _isFeeExempt[holder] = setOrRemove;
    }

    function enableFees(bool _feeEnabled) public onlyRole(ADMIN_ROLE) {
        feesEnabled = _feeEnabled;
    }

    function setBuyFees(uint16 liquidityFee, uint16 marketingFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee, "Fee Higher than Max Fees");
        BuyFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            totalFee: liquidityFee + marketingFee
        });
    }    
    
    function setSellFees(uint16 liquidityFee, uint16 marketingFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee, "Fee Higher than Max Fees");
        SellFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            totalFee: liquidityFee + marketingFee
        });

    }    
    
    function setTransferFees(uint16 liquidityFee, uint16 marketingFee) public onlyRole(ADMIN_ROLE) {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee, "Fee Higher than Max Fees");
        TransferFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            totalFee: liquidityFee + marketingFee
        });
    }    
    
    function setMaxFees(uint16 liquidityFee, uint16 marketingFee) public onlyRole(ADMIN_ROLE) {
        if(!Launch.launched){
            MaxFees = IFees({
                liquidityFee: liquidityFee,
                marketingFee: marketingFee,
                totalFee: liquidityFee + marketingFee
            });                
        } else {
            require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee, "Fee Higher than Max Fees");
            MaxFees = IFees({
                liquidityFee: liquidityFee,
                marketingFee: marketingFee,
                totalFee: liquidityFee + marketingFee
            });
        }
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        if (block.timestamp >= Launch.launchedAt + 24 hours && earlySellFees){
            SellFees = IFees({
                liquidityFee: 0,
                marketingFee: 1000,
                totalFee: 1000
            });
            earlySellFees = false;
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

        if(_totalFee == 0){return amount;}
        uint256 feeAmount = (amount * _totalFee) / feeDivisor;

        if (LiquiditySettings.autoLiquifyEnabled) {
            LiquiditySettings.liquidityFeeAccumulator += ((feeAmount * (BuyFees.liquidityFee + SellFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee) + (BuyFees.liquidityFee + SellFees.liquidityFee)));
        }
        if(burnFees){
            _burn(sender, feeAmount);
        } else {
            ERC20._transfer(sender, address(this), feeAmount);
        }
        return amount - feeAmount;
    }
}
