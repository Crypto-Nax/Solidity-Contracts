// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
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

contract Tokentest is Pausable, Ownable, ERC20 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;
    uint16 _totalFee;
    uint16 _reflectionFee;
    uint16 public _feeDivisor = 10_000;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _reflectionTotal;
    uint256 public _tFeeTotal;
    bool public _feesEnabled;
    mapping(address => uint256) public _balances;
    mapping(address => uint) _timeTillCooldown;
    mapping(address => uint) public _reflectionsOwned;
    mapping(address => bool) public _isBlacklisted;
    mapping(address => bool) public _isFeeExempt;
    mapping(address => bool) public _isLiquidityPair;
    mapping(address => bool) public _isLiquidityHolder;
    mapping(address => bool) public _isMaxWalletExempt;
    mapping(address => bool) public _isReflectionExempt;
    mapping(address => bool) public _isPreTrader;
    mapping(address => bool) public _routers;
    
    struct IFees {
        uint16 reflectionFee;
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 totalFee;
    }
    struct ILaunch {
        uint256 launchedAt;
        uint256 launchBlock;
        uint256 antiBlocks;
        bool tradingOpen;
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
        bool marketing;
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
    IRouter02 public immutable _initialRouter;
    address public immutable _initialPair;
    address public _marketingFeeReceiver;
    address[] _exempt;

    modifier lockTheSwap {
        LiquiditySettings.inSwap = true;
        _;
        LiquiditySettings.inSwap = false;
    }

    constructor(uint startingSupply, string memory name, string memory symbol, address initialRouter) ERC20(name, symbol) {
        uint supply = startingSupply*10**18;
        _reflectionTotal = (MAX - (MAX % supply));
        _reflectionsOwned[_msgSender()] = _reflectionTotal;
        IRouter02 router = IRouter02(initialRouter);
        _initialRouter = router;             
        address pair = IFactory(router.factory()).createPair(address(this), router.WETH());
        _initialPair = pair;

        setRouterOrPair(pair, 1, true);
        setRouterOrPair(address(router), 0, true);
        setLiquidityHolder(_msgSender(), true);

        setMaxWalletExempt(address(this), true);
        setMaxWalletExempt(_msgSender(), true);
        setMaxWalletExempt(pair, true);

        allowPreTrading(owner(), true);
        setLiquidityHolder(owner(), true);  

        _approve(_msgSender(), address(initialRouter), type(uint256).max);
        _approve(address(this), address(initialRouter), type(uint256).max);  

        CooldownInfo.cooldownLimit = 60;

        _mint(_msgSender(), supply);
    }
    // set launch
    function setTradingOpen(bool _tradingOpen, uint8 sniperblocks) public onlyOwner {
        require(sniperblocks <= 5);
        require(!Launch.launched);
        Launch.tradingOpen = _tradingOpen;
        FeesEnabled(_tradingOpen);
        setCooldownEnabled(_tradingOpen, _tradingOpen, 30);
        setNumTokensToSwap(1,1000);
        setTransactionLimits(_tradingOpen);
        setMaxTransactionAmount(1,100);
        setMaxWalletAmount(2,100);
        toggleSwap(_tradingOpen, 10);
        if(!Launch.launched) {
            setMaxFee(500,500,500, _tradingOpen);
            Launch.launched = _tradingOpen;
            Launch.antiBlocks = sniperblocks;
            Launch.launchedAt = block.timestamp; 
            Launch.launchBlock = block.number; 
            Launch.launchProtection = _tradingOpen;
        }
        emit TradingOpen();
    }

    //Return Balance Of Holder
    function balanceOf(address account) public view override returns (uint256) {
        if (_isReflectionExempt[account]) return _balances[account];
        return tokenFromReflection(_reflectionsOwned[account]);
    }

    // Allow Address For PreTrading
    function allowPreTrading(address account, bool allowed) public onlyOwner {
        require(_isPreTrader[account] != allowed, "TOKEN: Already enabled.");
        _isPreTrader[account] = allowed;
        emit PreTrader(account, allowed);
    }

    // Set Cooldown Function
    function setCooldownEnabled(bool onoff, bool offon, uint8 time) public onlyOwner {
        require(time <= CooldownInfo.cooldownLimit);
        CooldownInfo.cooldownTime = time;
        CooldownInfo.buycooldownEnabled = onoff;
        CooldownInfo.sellcooldownEnabled = offon;
        emit CooldownSettingsUpdated(onoff, offon, time);
    }

    // Exempt Or Include Holder From Fees
    function setFeeExempt(address holder, bool setOrRemove) public onlyOwner {
        _isFeeExempt[holder] = setOrRemove;
        emit HolderFeeExempt(holder, setOrRemove);
    }

    // Exempt Holder From Max Wallet Function
    function setMaxWalletExempt(address holder, bool setOrRemove) public onlyOwner{
        _isMaxWalletExempt[holder] = setOrRemove;
        emit MaxWalletExempt(holder, setOrRemove);
    }

    // Set Marketing Fee Receiver Function
    function setMarketingFeeReceiver(address receiver) public onlyOwner {
        _marketingFeeReceiver = receiver;
        emit MarketingFeeReceiverUpdated(receiver);
    }

    // Set Liquidity Holder Function
    function setLiquidityHolder(address holder, bool setOrRemove) public onlyOwner {
        _isLiquidityHolder[holder] = setOrRemove;
        emit LiquidityHoldersUpdated(holder, setOrRemove);
    }

    // Set Pair Or Router Function
    function setRouterOrPair(address addr, uint8 routerOrPair, bool setOrRemove) public onlyOwner {
        require(routerOrPair == 0 || routerOrPair == 1);
        if(routerOrPair == 0){
            _routers[addr] = setOrRemove;
            emit RouterOrPairUpdated(addr, routerOrPair, setOrRemove);
        } else {
            _isLiquidityPair[addr] = setOrRemove;
            emit RouterOrPairUpdated(addr, routerOrPair, setOrRemove);
        }
    }

    // Set Amount Of Tokens Required To Initiate A Swap
    function setNumTokensToSwap(uint256 percent, uint256 divisor) public onlyOwner {
        LiquiditySettings.numTokensToSwap = (totalSupply() * percent) / divisor;
        emit NumTokensToSwapUpdated((totalSupply() * percent) / divisor);
    }

    // Set Fee Functions
    function FeesEnabled(bool enabled) public onlyOwner {
        _feesEnabled = enabled;
        emit AreFeesEnabled(enabled);
    }

    function setBuyFees(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee) public onlyOwner {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee && reflectionFee <= MaxFees.reflectionFee);
        BuyFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            reflectionFee: reflectionFee,
            totalFee: liquidityFee + marketingFee + reflectionFee
        });
        emit BuyFeesUpdated(liquidityFee, marketingFee, reflectionFee);
    }

    function setSellFees(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee) public onlyOwner {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee && reflectionFee <= MaxFees.reflectionFee);
        SellFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            reflectionFee: reflectionFee,
            totalFee: liquidityFee + marketingFee +  reflectionFee
        });
        emit SellFeesUpdated(liquidityFee, marketingFee, reflectionFee);
    }

    function setTransferFees(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee) public onlyOwner {
        require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee && reflectionFee <= MaxFees.reflectionFee);
        TransferFees = IFees({
            liquidityFee: liquidityFee,
            marketingFee: marketingFee,
            reflectionFee: reflectionFee,
            totalFee: liquidityFee + marketingFee + reflectionFee
        });
        emit TransferFeesUpdated(liquidityFee, marketingFee, reflectionFee);
    }
        
    function setMaxFee(uint16 reflectionFee, uint16 liquidityFee, uint16 marketingFee, bool resetFees) public onlyOwner {
        if(!Launch.launched){
            MaxFees = IFees({
                reflectionFee: reflectionFee,
                liquidityFee: liquidityFee,
                marketingFee: marketingFee,
                totalFee: reflectionFee + liquidityFee + marketingFee
            });
            setBuyFees(liquidityFee, marketingFee, reflectionFee);                
            setSellFees(liquidityFee, marketingFee, reflectionFee);
            setTransferFees(liquidityFee / (10), marketingFee/ (10), reflectionFee / (10));
        }else{
            require(liquidityFee <= MaxFees.liquidityFee && marketingFee <= MaxFees.marketingFee && reflectionFee <= MaxFees.reflectionFee);
            MaxFees = IFees({
                reflectionFee: reflectionFee,
                liquidityFee: liquidityFee,
                marketingFee: marketingFee,
                totalFee: reflectionFee + liquidityFee + marketingFee
            });
            if(resetFees){
                setBuyFees(liquidityFee, marketingFee, reflectionFee);                
                setSellFees(liquidityFee, marketingFee, reflectionFee);
                setTransferFees(liquidityFee / (10), marketingFee/ (10), reflectionFee / (10));
            }
        }
        emit MaxFeesUpdated(reflectionFee, liquidityFee, marketingFee, resetFees);
    }

    // Sets Fees For Transfers
    function setFee(address sender, address recipient) internal {
        if(_feesEnabled){
            if (_isLiquidityPair[recipient]) {
                if(_totalFee != SellFees.marketingFee + SellFees.liquidityFee){
                    _totalFee = SellFees.marketingFee + SellFees.liquidityFee;            
                }
                if(_reflectionFee != SellFees.reflectionFee){
                    _reflectionFee = SellFees.reflectionFee;
                }
            } else if(_isLiquidityPair[sender]){
                if(_totalFee != BuyFees.marketingFee + BuyFees.liquidityFee){
                    _totalFee = BuyFees.marketingFee + BuyFees.liquidityFee;            
                }
                if(_reflectionFee != BuyFees.reflectionFee){
                    _reflectionFee = BuyFees.reflectionFee;
                }
            } else {
                if(_totalFee != TransferFees.marketingFee + TransferFees.liquidityFee){
                    _totalFee = TransferFees.marketingFee + TransferFees.liquidityFee;            
                }
                if(_reflectionFee != TransferFees.reflectionFee){
                    _reflectionFee = TransferFees.reflectionFee;
                }
            }
            if(block.number <= Launch.launchBlock + Launch.antiBlocks){
                _totalFee += 2500; // Adds 25% tax onto original tax
            }
        }
        // removes fee if sender or recipient is fee excluded or if fees are disabled
        if (_isFeeExempt[sender] || _isFeeExempt[recipient] || !_feesEnabled) {
            if(_totalFee != 0 && _reflectionFee != 0){
                _totalFee = 0;
                _reflectionFee = 0;
            }
        }
    }

    // Transaction function
    function setMaxTransactionAmount(uint16 percent, uint16 divisor) public onlyOwner {
        require((totalSupply() * percent) / divisor >= totalSupply() / 1000, "Max Transaction Amount must be above 0.1% of the total supply");

        TransactionSettings.maxTransactionAmount = (totalSupply() * percent) / divisor;
        emit MaxTransactionUpdated((totalSupply() * percent) / divisor);
    }

    function setMaxWalletAmount(uint16 percent, uint16 divisor) public onlyOwner {
        require((totalSupply() * percent) / divisor >= totalSupply() / 1000, "Max Wallet Amount must be above 0.1% of the total supply");
        TransactionSettings.maxWalletAmount = (totalSupply() * percent) / divisor;
        emit MaxWalletUpdated((totalSupply() * percent) / divisor);
    }

    function setTransactionLimits(bool limited) public onlyOwner {
        TransactionSettings.txLimits = limited;
    }

    // Blacklist Functions
    function blockBots(address[] memory bots_, bool enabled) public onlyOwner {
        for (uint256 i = 0; i < bots_.length; i++) {
            _isBlacklisted[bots_[i]] = enabled;
            emit SniperBlacklisted(bots_[i], enabled);
        }
    }

    function _setSniperStatus(address account, bool blacklisted) internal {
        if(_isLiquidityPair[account] || account == address(this) || account == address(_initialRouter) || _isFeeExempt[account]) {revert();}
        
        if (blacklisted == true) {
            _isBlacklisted[account] = true;
        } else {
            _isBlacklisted[account] = false;
        }
        emit SniperBlacklisted(account, blacklisted);
    }

    function turnOff() internal {
        Launch.launchProtection = false;
    }

    // Receive Tokens To Marketing Instead Of Eth
    function toggleMarketing(bool enabled) public onlyOwner {
        LiquiditySettings.marketing = enabled;
        emit MarketingToggled(enabled);
    }

    // Contract Swap Function
    function toggleSwap(bool swapEnabled, uint8 swapInterval) public onlyOwner {
        LiquiditySettings.swapEnabled = swapEnabled;
        LiquiditySettings.swapInterval = swapInterval;
        emit ContractSwap(swapEnabled, swapInterval);
    }

    // In Contract Airdrop 
    function airDropTokens(address[] memory addresses, uint256[] memory amounts) external {
        require(addresses.length == amounts.length, "Lengths do not match.");
        for (uint8 i = 0; i < addresses.length; i++) {
            require(balanceOf(_msgSender()) >= amounts[i]);
            IERC20(address(this)).safeTransfer(addresses[i], amounts[i]*10**decimals());
            emit TokensAirdropped(addresses[i], amounts[i]*10**decimals());
        }
    }

    // Pause Or Unpause Trading
    function pause() public onlyOwner() {
        _pause();
        emit Paused(true);
    }

    function unpause() public onlyOwner() {
        _unpause();
        emit Unpaused(true);
    }

    // Adds Eth And Token To Liqudity
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_initialRouter), type(uint256).max);  

        // add the liquidity
        _initialRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(owner()),
            block.timestamp
        );
    }

    // Swaps Half Of numTokensToSwap For Eth And Pairs With The Remaining Half For Liqudity
    function swapAndLiquify() private lockTheSwap {
        uint256 liquidityTokens = LiquiditySettings.numTokensToSwap / 2;
        swapTokens(liquidityTokens);
        uint256 toLiquidity = address(this).balance;
        addLiquidity(liquidityTokens, toLiquidity);
        emit SwapForLiquidity(toLiquidity, liquidityTokens);
        LiquiditySettings.liquidityFeeAccumulator -= LiquiditySettings.numTokensToSwap;        
    }

    // Swaps Tokens And Sends Eth To Marketing
    function swapForMarketing() private lockTheSwap {
        swapTokens(LiquiditySettings.numTokensToSwap);
        uint256 toMarketing = address(this).balance;
        payable(_marketingFeeReceiver).transfer(toMarketing);
        emit SwapForMarketing(toMarketing);
    }

    // Swaps Tokens for Eth
    function swapTokens(uint256 tokenAmount) private {
        // generate the pancakeswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _initialRouter.WETH();

        _approve(address(this), address(_initialRouter), type(uint256).max);  

        // make the swap
        _initialRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of Eth
            path,
            address(this),
            block.timestamp
        );
    }

    // Reflection Functions
    function deliver(uint256 tAmount) private {
        address sender = _msgSender();
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _reflectionTotal = _reflectionTotal.sub(rAmount);
        if(_isReflectionExempt[msg.sender])
            _balances[sender] =  _balances[sender].sub(tAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= totalSupply(), "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _reflectionTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        require(!_isReflectionExempt[account], "Account is already excluded");
        if(_reflectionsOwned[account] > 0) {
            _balances[account] = tokenFromReflection(_reflectionsOwned[account]);
        }
        _isReflectionExempt[account] = true;
        _exempt.push(account);
        emit AccountExemptFromReflections(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isReflectionExempt[account], "Account is not excluded");
        for (uint256 i = 0; i < _exempt.length; i++) {
            if (_exempt[i] == account) {
                _exempt[i] = _exempt[_exempt.length - 1];
                _balances[account] = 0;
                _isReflectionExempt[account] = false;
                _exempt.pop();
                break;
            }
        }
        emit AccountIncludedInReflections(account);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _reflectionTotal = _reflectionTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tFees) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tFees, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tFees);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = (tAmount * _reflectionFee) / _feeDivisor;
        uint256 tFees = (tAmount * _totalFee) / _feeDivisor;
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tFees);
        return (tTransferAmount, tFee, tFees);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tFees, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rFees = tFees.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rFees);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _reflectionTotal;
        uint256 tSupply = totalSupply();      
        for (uint256 i = 0; i < _exempt.length; i++) {
            if (_reflectionsOwned[_exempt[i]] > rSupply || balanceOf(_exempt[i]) > tSupply) return (_reflectionTotal, totalSupply());
            rSupply = rSupply.sub(_reflectionsOwned[_exempt[i]]);
            tSupply = tSupply.sub(balanceOf(_exempt[i]));
        }
        if (rSupply < _reflectionTotal.div(totalSupply())) return (_reflectionTotal, totalSupply());
        return (rSupply, tSupply);
    }
    
    function getCirculatingSupply() external view returns(uint256){
        return totalSupply() - balanceOf(address(0xDead));
    }

    function _takeFees(uint256 tFees) private {
        uint256 currentRate = _getRate();
        uint256 rFees = tFees.mul(currentRate);
        _reflectionsOwned[address(this)] = _reflectionsOwned[address(this)].add(rFees);
        if(_isReflectionExempt[address(this)])
            _balances[address(this)] = _balances[address(this)].add(tFees);
    }

    function _takeMarketing(uint256 marketing) private {
        uint256 currentRate =  _getRate();
        uint256 rMarketing = marketing.mul(currentRate);
        _reflectionsOwned[_marketingFeeReceiver] = _reflectionsOwned[_marketingFeeReceiver].add(rMarketing);
        if(_isReflectionExempt[_marketingFeeReceiver])
            _balances[_marketingFeeReceiver] = _balances[_marketingFeeReceiver].add(marketing);
     
    }

    // Transfer Limits
    function limits(address from, address to) private view returns (bool) {
        return from != owner()
            && to != owner()
            && tx.origin != owner()
            && !_isLiquidityHolder[from]
            && !_isLiquidityHolder[to]
            && to != address(0xdead)
            && to != address(0)
            && from != address(this);
    }


    // Transfer functions
    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused() {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");            
        require(!_isBlacklisted[from], "TOKEN: Your account is blacklisted!");
        require(!_isBlacklisted[to], "TOKEN: Your account is blacklisted!");
        require(amount > 0, "BEP20: Transfer amount must be greater than zero");
        if(LiquiditySettings.inSwap) { 
            _basicTransfer(from, to, amount);
        } else {
            if(from != owner() && to != owner()){
                if(!Launch.tradingOpen){
                    require(_isPreTrader[from] || _isPreTrader[to]);
                }
                if (limits(from, to)) {
                    if(Launch.tradingOpen && Launch.launched && TransactionSettings.txLimits){
                        if(!_isMaxWalletExempt[to]){
                            require(amount <= TransactionSettings.maxTransactionAmount && balanceOf(to) + amount <= TransactionSettings.maxWalletAmount, "TOKEN: Amount exceeds Transaction size");
                        }
                        if (_isLiquidityPair[from] && !_routers[to] && !_isFeeExempt[to] && CooldownInfo.buycooldownEnabled) {
                            require(_timeTillCooldown[to] < block.timestamp);
                            _timeTillCooldown[to] = block.timestamp + (CooldownInfo.cooldownTime);
                        } else if (!_isLiquidityPair[from] && !_isFeeExempt[from] && CooldownInfo.sellcooldownEnabled){
                            require(_timeTillCooldown[from] <= block.timestamp);
                            _timeTillCooldown[from] = block.timestamp + (CooldownInfo.cooldownTime);
                        }                     
                    }
                }      
                if(LiquiditySettings.swapEnabled && !LiquiditySettings.inSwap && balanceOf(address(this)) >= LiquiditySettings.numTokensToSwap && _isLiquidityPair[to]){
                    if(LiquiditySettings.liquidityFeeAccumulator >= LiquiditySettings.numTokensToSwap && block.timestamp >= LiquiditySettings.lastSwap + LiquiditySettings.swapInterval){
                        swapAndLiquify();
                        LiquiditySettings.lastSwap = block.timestamp;
                    } else {
                        if(block.timestamp >= LiquiditySettings.lastSwap + LiquiditySettings.swapInterval){
                            swapForMarketing();
                            LiquiditySettings.lastSwap = block.timestamp;
                        }
                    }
                }
            }
            // transfer amount, it will set fees and auto blacklist snipers
            _tokenTransfer(from,to,amount);
        }
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if(Launch.launched){
            setFee(sender, recipient);
            if(Launch.launchProtection){
                if(Launch.launchBlock + Launch.antiBlocks <= block.number) {
                    turnOff();
                }
                if (_isLiquidityPair[sender] && !_routers[recipient] && !_isFeeExempt[recipient]) {
                    if (block.number  <= Launch.launchBlock + Launch.antiBlocks) {
                        if(!_isLiquidityPair[recipient]){
                            _setSniperStatus(recipient, true);
                        }
                    }
                }
            }
        }

        // transfers and takes fees
        if(!Launch.tradingOpen){
            _basicTransfer(sender, recipient, amount);
        } else if (_isReflectionExempt[sender] && !_isReflectionExempt[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isReflectionExempt[sender] && _isReflectionExempt[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isReflectionExempt[sender] && _isReflectionExempt[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _basicTransfer(address sender, address recipient, uint256 tAmount) private {
        uint256 rAmount = tAmount.mul(_getRate());
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _reflectionsOwned[recipient] = _reflectionsOwned[recipient].add(rAmount);
        emit Transfer(sender, recipient, tAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tFees) = _getValues(tAmount);
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _reflectionsOwned[recipient] = _reflectionsOwned[recipient].add(rTransferAmount);
        if(!LiquiditySettings.marketing){
            _takeFees(tFees);
            uint16 taxCorrection = (BuyFees.reflectionFee + SellFees.reflectionFee + TransferFees.reflectionFee);
            LiquiditySettings.liquidityFeeAccumulator += (tFees * (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee + TransferFees.totalFee) - taxCorrection) + (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee);
        } else {
            _takeMarketing(tFees);
        }      
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);      
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tFees) = _getValues(tAmount);
        _balances[sender] = _balances[sender].sub(tAmount);
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _balances[recipient] = _balances[recipient].add(tTransferAmount);
        _reflectionsOwned[recipient] = _reflectionsOwned[recipient].add(rTransferAmount);        
        if(!LiquiditySettings.marketing){
            _takeFees(tFees);
            uint16 taxCorrection = (BuyFees.reflectionFee + SellFees.reflectionFee + TransferFees.reflectionFee);
            LiquiditySettings.liquidityFeeAccumulator += (tFees * (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee + TransferFees.totalFee) - taxCorrection) + (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee);
        } else {
            _takeMarketing(tFees);
        }        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tFees) = _getValues(tAmount);
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _balances[recipient] = _balances[recipient].add(tTransferAmount);
        _reflectionsOwned[recipient] = _reflectionsOwned[recipient].add(rTransferAmount);           
        if(!LiquiditySettings.marketing){
            _takeFees(tFees);
            uint16 taxCorrection = (BuyFees.reflectionFee + SellFees.reflectionFee + TransferFees.reflectionFee);
            LiquiditySettings.liquidityFeeAccumulator += (tFees * (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee + TransferFees.totalFee) - taxCorrection) + (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee);
        } else {
            _takeMarketing(tFees);
        }       
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tFees) = _getValues(tAmount);
        _balances[sender] = _balances[sender].sub(tAmount);
        _reflectionsOwned[sender] = _reflectionsOwned[sender].sub(rAmount);
        _reflectionsOwned[recipient] = _reflectionsOwned[recipient].add(rTransferAmount);   
        if(!LiquiditySettings.marketing){
            _takeFees(tFees);
            uint16 taxCorrection = (BuyFees.reflectionFee + SellFees.reflectionFee + TransferFees.reflectionFee);
            LiquiditySettings.liquidityFeeAccumulator += (tFees * (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee)) / ((BuyFees.totalFee + SellFees.totalFee + TransferFees.totalFee) - taxCorrection) + (BuyFees.liquidityFee + SellFees.liquidityFee + TransferFees.liquidityFee);
        } else {
            _takeMarketing(tFees);
        }        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    event AccountExemptFromReflections(address holder);
    event AccountIncludedInReflections(address holder);
    event AreFeesEnabled(bool enabled);
    event BuyFeesUpdated(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee);
    event ContractSwap(bool swapEnabled, uint8 swapInterval);
    event CooldownSettingsUpdated(bool buycooldown, bool sellcooldown, uint8 cooldownTime);
    event HolderFeeExempt(address holder, bool setOrRemove);
    event LiquidityHoldersUpdated(address indexed holder, bool setOrRemove);   
    event MaxFeesUpdated(uint16 reflectionFee, uint16 liquidityFee, uint16 marketingFee, bool feesReset);
    event MaxWalletExempt(address holder, bool setOrRemove);
    event MarketingFeeReceiverUpdated(address receiver);
    event MarketingToggled(bool enabled);
    event MaxWalletUpdated(uint newMaxWalletAmount);
    event MaxTransactionUpdated(uint newMaxTransactionAmount);
    event NumTokensToSwapUpdated(uint minTokensBeforeSwap);
    event Paused(bool paused);
    event PreTrader(address account, bool allowed);
    event RouterOrPairUpdated(address indexed addr, uint routerOrPair, bool setOrRemove);
    event Unpaused(bool unpaused);
    event SellFeesUpdated(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee);
    event SniperBlacklisted(address account, bool enabled);
    event SwapForLiquidity(uint256 eth, uint256 tokensIntoLiquidity);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapForMarketing(uint256 eth);
    event TokensAirdropped(address indexed holder, uint indexed amount);
    event TradingOpen();
    event TransferFeesUpdated(uint16 liquidityFee, uint16 marketingFee, uint16 reflectionFee);
}
