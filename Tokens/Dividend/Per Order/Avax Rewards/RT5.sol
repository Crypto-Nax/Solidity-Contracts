//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IJoeFactory.sol";
import "./DividendDistributor.sol";
import './Verifier.sol';
import "./Ownable.sol";

// made by https://github.com/Crypto-Nax https://twitter.com/Crypto_Nax6o4
contract Token is IERC20, Context, Ownable {
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address public autoLiquidityReceiver;
    address public marketingFeeReceiver;
    address public pair;
    IJoeRouter02 public router;
    IDividendDistributor public distributor;
    Verify public verifier;
    string constant _name = "TOKEN";
    string constant _symbol = "TOKEN";
    uint8 constant _decimals = 9;

    uint256 constant _initialSupply = 180_000_000; // put supply amount here
    uint256 _totalSupply = _initialSupply * (10**_decimals); // total supply amount
    // uint256 public _maxTxAmount = (_totalSupply * (1)) / (100);
    mapping(address => bool) lpPairs;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isTxLimitExempt;
    mapping(address => bool) isDividendExempt;
    mapping(address => bool) authorizations;

    struct IFees {
        uint256 liquidityFee;
        uint256 buybackFee;
        uint256 reflectionFee;
        uint256 marketingFee;
        uint256 totalFee;
    }
    IFees public BuyFees;
    IFees public SellFees;
    IFees public TransferFees;
    IFees public MaxFees =
        IFees({
            reflectionFee: 15,
            buybackFee: 5,
            liquidityFee: 5,
            marketingFee: 5,
            totalFee: 30
        });
    struct ItxSettings {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        bool txLimits;
    }

    ItxSettings public txSettings;
    uint256 feeDenominator = 100;
    uint256 public sellMultiplier;
    uint256 public constant maxSellMultiplier = 3;
    uint256 marketingFees;
    uint256 liquidityFeeAccumulator;
    bool public feeEnabled;
    bool public autoLiquifyEnabled;
    bool inSwap;
    bool public autoClaimEnabled;
    bool swapEnabled;
    bool autoBuybackEnabled;
    bool public fundRewards;
    uint256 autoBuybackCap;
    uint256 autoBuybackAccumulator;
    uint256 autoBuybackAmount;
    uint256 autoBuybackBlockPeriod;
    uint256 autoBuybackBlockLast;
    uint256 distributorGas = 500000;
    uint256 swapThreshold = _totalSupply / 4000; // 0.025%
    uint256 lastSwap;
    uint256 public swapInterval = 30 seconds;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    constructor(address payable m) {
        authorizations[msg.sender] = true;
        router = IJoeRouter02(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
        pair = IJoeFactory(router.factory()).createPair(router.WAVAX(), address(this));
        lpPairs[pair] = true;
        _allowances[address(this)][address(router)] = type(uint256).max;
        distributor = new DividendDistributor(address(router));        
        verifier = new Verifier([address(this), owner(), address(router), address(pair)]);

        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;
        isTxLimitExempt[msg.sender] = true;
        isTxLimitExempt[address(this)] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;

        autoLiquidityReceiver = m;
        marketingFeeReceiver = m;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function updateRouter(address _router, address _pair) external onlyOwner {
        router = IJoeRouter02(_router);
        pair = _pair;
    }    
    
    function setLpPair(address pairs, bool enabled) public onlyOwner {
        lpPairs[pairs] = enabled;
        verifier.setLpPair(pairs, enabled);
    }

    function updateVerifier(address token, address _router) public onlyOwner {
        verifier.updateToken(token);
        verifier.updateRouter(_router);
    }

    function updateDividendDistributor(address token, address _router) public onlyOwner{
        distributor.updateDividendDistributor(token, _router);
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
        return owner();
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
        return from != owner()
            && to != owner()
            && tx.origin != owner()
            && !isAuthorized(from)
            && !isAuthorized(to)
            && to != address(0xdead)
            && to != address(0)
            && from != address(this);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        if(limits(sender, recipient)){
            checkLaunched(sender);
            if(launched()){
                if(lpPairs[sender] || lpPairs[recipient]){
                    if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]){
                        checkTxLimit(sender, amount);
                    }
                }
                if(!lpPairs[recipient] && recipient != address(router)){
                    if(!isTxLimitExempt[recipient]){
                        require(balanceOf(recipient) + amount <= txSettings.maxWalletAmount);
                    }
                }
            }
        }

        if (shouldSwapBack()) {
            swapBack();
        }
        if (shouldAutoBuyback()) {
            triggerAutoBuyback();
        }

        if(launched()){
            if(limits(sender, recipient)) {
                verifier.verifyUser(sender, recipient);
            }
        }

        _balances[sender] -= amount;

        uint256 amountReceived = shouldTakeFee(sender)
            ? takeFee(sender, recipient, amount)
            : amount;
        _balances[recipient] += amountReceived;

        if (!isDividendExempt[sender] && balanceOf(sender) >= holdAmount()) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }
        if (!isDividendExempt[recipient] && balanceOf(recipient) >= holdAmount() ) {
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
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function setSellMultiplier(uint256 SM) external authorized {
        require(SM <= maxSellMultiplier);
        sellMultiplier = SM;
    }

    function checkLaunched(address sender) internal view {
        require(launched() || isAuthorized(sender), "Pre-Launch Protection");
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= txSettings.maxTxAmount || isTxLimitExempt[sender],"TX Limit Exceeded");
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return feeEnabled && !isFeeExempt[sender];
    }

    function sellingFee() internal view returns (uint256) {
        return SellFees.totalFee * sellMultiplier;
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        if (isFeeExempt[sender] || isFeeExempt[receiver]) {
            return amount;
        }
        uint256 totalFee;
        if (lpPairs[receiver]) {
            if(sellMultiplier >= 2){
                totalFee = sellingFee();
            } else {
                totalFee = SellFees.totalFee;
            }
        } else if(lpPairs[sender]){
            totalFee = BuyFees.totalFee;
        } else {
            totalFee = TransferFees.totalFee;
        }

        uint256 feeAmount = (amount * totalFee) / feeDenominator;

        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);

        if (receiver == pair && autoLiquifyEnabled) {
            liquidityFeeAccumulator =
                liquidityFeeAccumulator +
                ((feeAmount * (BuyFees.liquidityFee + SellFees.liquidityFee)) /
                    ((BuyFees.totalFee + SellFees.totalFee) +
                        (BuyFees.liquidityFee + SellFees.liquidityFee)));
        }

        return amount - feeAmount;
    }

    function shouldSwapBack() internal view returns (bool) {
        return
            !lpPairs[msg.sender] &&
            !inSwap &&
            swapEnabled &&
            block.timestamp >= lastSwap + swapInterval &&
            _balances[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {
        lastSwap = block.timestamp;
        if (liquidityFeeAccumulator >= swapThreshold && autoLiquifyEnabled) {
            liquidityFeeAccumulator = liquidityFeeAccumulator - swapThreshold;
            uint256 amountToLiquify = swapThreshold / 2;

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WAVAX();

            uint256 balanceBefore = address(this).balance;

            router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
                amountToLiquify,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountAvax = address(this).balance - (balanceBefore);

            router.addLiquidityAVAX{value: amountAvax}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );

            emit AutoLiquify(amountAvax, amountToLiquify);
        } else {
            uint256 amountToSwap = swapThreshold;

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WAVAX();

            uint256 balanceBefore = address(this).balance;

            router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
                amountToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountAvax = address(this).balance - (balanceBefore);

            uint256 amountAvaxReflection = (amountAvax *
                (BuyFees.reflectionFee + SellFees.reflectionFee)) /
                (BuyFees.totalFee + SellFees.totalFee);
            uint256 amountAvaxMarketing = (amountAvax *
                (BuyFees.marketingFee + SellFees.marketingFee)) /
                (BuyFees.totalFee + SellFees.totalFee);

            if(fundRewards){
                try distributor.deposit{value: amountAvaxReflection}() {} catch {}
                (bool success, ) = payable(marketingFeeReceiver).call{
                value: amountAvaxMarketing,
                gas: 30000
            }("");
            if (success) {
                marketingFees += amountAvaxMarketing;
            }
            } else {
                payable(marketingFeeReceiver).transfer(amountAvaxMarketing);
                marketingFees += amountAvaxMarketing;
            }

            emit SwapBack(amountToSwap, amountAvax);
        }
    }

    function shouldAutoBuyback() internal view returns (bool) {
        return
            msg.sender != pair &&
            !inSwap &&
            autoBuybackEnabled &&
            autoBuybackBlockLast + autoBuybackBlockPeriod <= block.number &&
            address(this).balance >= autoBuybackAmount;
    }

    function buybackWEI(uint256 amount) external authorized {
        _buyback(amount);
    }

    function buybackAvax(uint256 amount) external authorized {
        _buyback(amount * (10**18));
    }

    function manualDeposit(uint256 amount) external onlyOwner {
        try distributor.deposit{value: amount}() {} catch {}
    }

    function _buyback(uint256 amount) internal {
        buyTokens(amount, marketingFeeReceiver);
        emit Buyback(amount);
    }

    function triggerAutoBuyback() internal {
        buyTokens(autoBuybackAmount, DEAD);
        autoBuybackBlockLast = block.number;
        autoBuybackAccumulator = autoBuybackAccumulator + autoBuybackAmount;
        if (autoBuybackAccumulator > autoBuybackCap) {
            autoBuybackEnabled = false;
        }
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        address[] memory path = new address[](2);
        path[0] = router.WAVAX();
        path[1] = address(this);

        router.swapExactAVAXForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(0, path, to, block.timestamp);
    }

    function setAutoBuybackSettings(bool _enabled, uint256 _cap, uint256 _amount, uint256 _period) external authorized {
        autoBuybackEnabled = _enabled;
        autoBuybackCap = _cap;
        autoBuybackAccumulator = 0;
        autoBuybackAmount = _amount;
        autoBuybackBlockPeriod = _period;
        autoBuybackBlockLast = block.number;
        emit AutoBuybackSettingsUpdated(_enabled, _cap, _amount, _period);
    }

    function launched() internal view returns (bool) {
        return verifier.getLaunchedAt() != 0;
    }

    function launch(uint256 blockAmount) public onlyOwner{
        require(blockAmount <= 5);
        require(!launched());
        swapEnabled = true;
        autoLiquifyEnabled = true;
        autoClaimEnabled = true;        
        verifier.checkLaunch(block.number, true, true, blockAmount);
        setBuyFees(2, 1, 9, 3);
        setSellFees(2, 1, 9, 3);
        setTransferFees(1,1,1,1);
        setTxLimit(1,100);
        setMaxWallet(2,100);
        fundRewards = true;
        feeEnabled = true;
        emit Launch();
    }

    function setTxLimit(uint256 percent, uint256 divisor) public authorized {
        require(percent >= 1 && divisor <= 1000);
        txSettings.maxTxAmount = (_totalSupply * (percent)) / (divisor);
        emit TxLimitUpdated(txSettings.maxTxAmount);
    }

    function setMaxWallet(uint256 percent, uint256 divisor) public authorized {
        require(percent >= 1 && divisor <= 1000);
        txSettings.maxWalletAmount = (_totalSupply * percent) / divisor;
        emit WalletLimitUpdated(txSettings.maxWalletAmount);
    }

    function setIsDividendExempt(address holder, bool exempt) external authorized {
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
        if(exempt == true) {
            verifier.feeExcluded(holder);
        } else {
            verifier.feeIncluded(holder);
        }
        emit FeeExemptUpdated(holder, exempt);
    }

    function setBlackListStatus(address account, bool blacklisted) external onlyOwner{
        verifier.setSniperStatus(account, blacklisted);
    }

    function setIsTxLimitExempt(address holder, bool exempt) external authorized{
        isTxLimitExempt[holder] = exempt;
        emit TxLimitExemptUpdated(holder, exempt);
    }

    function setBuyFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee);
        BuyFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee
        });
    }

    function FeesEnabled(bool _enabled) external onlyOwner {
        feeEnabled = _enabled;
        emit areFeesEnabled(_enabled);
    }

    function setSellFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee);
        SellFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee
        });
    }

    function setTransferFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee);
        TransferFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee
        });
    }

    function setFeeReceivers(address _autoLiquidityReceiver, address _marketingFeeReceiver) external onlyOwner {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        marketingFeeReceiver = _marketingFeeReceiver;
        emit FeeReceiversUpdated(_autoLiquidityReceiver, _marketingFeeReceiver);
    }

    function setCooldownEnabled(bool buy, bool sell, uint256 cooldown) external authorized {
        verifier.setCooldownEnabled(buy, sell);
        verifier.setCooldown(cooldown);
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external authorized{
        swapEnabled = _enabled;
        swapThreshold = (_totalSupply * (_amount)) / (10000);
        emit SwapBackSettingsUpdated(_enabled, _amount);
    }

    function setAutoLiquifyEnabled(bool _enabled) external authorized {
        autoLiquifyEnabled = _enabled;
        emit AutoLiquifyUpdated(_enabled);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldReq) external authorized {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution, _minHoldReq);
    }

    function setDistributorSettings(uint256 gas, bool _autoClaim) external authorized {
        require(gas <= 1000000);
        distributorGas = gas;
        autoClaimEnabled = _autoClaim;
        emit DistributorSettingsUpdated(gas, _autoClaim);
    }

    function getAccumulatedFees() external view returns (uint256) {
        return marketingFees;
    }

    function getCoolDownSettings() public view returns(bool buyCooldown, bool sellCooldown, uint256 coolDownTime, uint256 coolDownLimit) {
        return verifier.getCoolDownSettings();
    }
    
    function getLaunchedAt() external view returns(uint256 launchedAt){
        return verifier.getLaunchedAt();
    }

    function getAutoBuybackSettings() external view returns (bool,uint256,uint256,uint256,uint256,uint256){
        return ( autoBuybackEnabled, autoBuybackCap, autoBuybackAccumulator, autoBuybackAmount, autoBuybackBlockPeriod, autoBuybackBlockLast);
    }

    function getAutoLiquifySettings() external view returns (bool, uint256) {
        return (autoLiquifyEnabled, liquidityFeeAccumulator);
    }

    function getSwapBackSettings() external view returns (bool, uint256) {
        return (swapEnabled, swapThreshold);
    }

    function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return distributor.getShareholderInfo(shareholder);
    }

    function getAccountInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256) {
        return distributor.getAccountInfo(shareholder);
    }
    function holdAmount() public view returns(uint256) {
        return distributor.holdAmount();
    }

    function getBlacklistStatus(address account) external view returns(bool){
        return verifier.getBlacklistStatus(account);
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        require(amountPercentage <= 100);
        uint256 amountAvax = address(this).balance;
        payable(marketingFeeReceiver).transfer(
            (amountAvax * amountPercentage) / 100
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

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    event Authorized(address adr);
    event Unauthorized(address adr);
    event Launch();
    event AutoLiquify(uint256 amountAvax, uint256 amountToken);
    event SwapBack(uint256 amountToken, uint256 amountAvax);
    event Buyback(uint256 amountAvax);
    event AutoBuybackSettingsUpdated(bool enabled, uint256 cap, uint256 amount, uint256 period);
    event TxLimitUpdated(uint256 amount);
    event WalletLimitUpdated(uint256 amount);
    event DividendExemptUpdated(address holder, bool exempt);
    event FeeExemptUpdated(address holder, bool exempt);
    event TxLimitExemptUpdated(address holder, bool exempt);
    event FeeReceiversUpdated(address autoLiquidityReceiver, address marketingFeeReceiver);
    event SwapBackSettingsUpdated(bool enabled, uint256 amount);
    event areFeesEnabled(bool _enabled);
    event AutoLiquifyUpdated(bool enabled);
    event DistributorSettingsUpdated(uint256 gas, bool autoClaim);
    event WalletBanStatusUpdated(address user, bool banned);
}
