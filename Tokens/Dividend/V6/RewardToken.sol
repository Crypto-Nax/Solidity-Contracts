//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IDexFactory.sol";
import "./DividendDistributor.sol";
import "./Staking.sol";

contract Token is IBEP20, Context {
    address public owner;
    address public autoLiquidityReceiver;
    address public marketingFeeReceiver;
    address public stakingFeeReceiver;
    address public pair;
    IDEXRouter public router;
    IDividendDistributor public distributor;

    string constant _name = "TOKEN";
    string constant _symbol = "TOKEN";
    uint8 constant _decimals = 9;

    uint256 constant _initialSupply = 180_000_000; // put supply amount here
    uint256 _totalSupply = _initialSupply * (10**_decimals); // total supply amount

    mapping(address => bool) public lpPairs;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => uint256) buycooldown;
    mapping(address => uint256) sellcooldown;
    mapping(address => bool) isFeeExempt;
    mapping(address => bool) isTxLimitExempt;
    mapping(address => bool) isDividendExempt;
    mapping(address => bool) public bannedUsers;
    mapping(address => bool) authorizations;
    Staking public stake;
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
    Icooldown public cooldownInfo;
    struct IFees {
        uint256 liquidityFee;
        uint256 buybackFee;
        uint256 reflectionFee;
        uint256 marketingFee;
        uint256 stakeFee;
        uint256 totalFee;
    }
    IFees public BuyFees;
    IFees public SellFees;
    IFees public TransferFees;
    IFees public MaxFees =
        IFees({
            reflectionFee: 150,
            buybackFee: 50,
            liquidityFee: 50,
            stakeFee: 50,
            marketingFee: 50,
            totalFee: 300 // 30% on launch
        });
    struct ItxSettings {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        bool txLimits;
    }
    uint256 sniperTaxBlocks;
    ItxSettings public txSettings;
    uint256 feeDenominator = 1000;
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
    bool public enableStaking;
    bool public fundRewards;
    uint256 autoBuybackCap;
    uint256 autoBuybackAccumulator;
    uint256 autoBuybackAmount;
    uint256 autoBuybackBlockPeriod;
    uint256 autoBuybackBlockLast;
    uint256 distributorGas = 500000;
    uint256 swapThreshold = _totalSupply / 4000; // 0.025%
    uint256 lastSwap;
    uint256 swapInterval = 30 seconds;
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }

    constructor(address payable m) {
        owner = _msgSender();
        authorizations[owner] = true;
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));
        lpPairs[pair] = true;
        _allowances[address(this)][address(router)] = type(uint256).max;
        _allowances[_msgSender()][address(router)] = type(uint256).max;

        distributor = new DividendDistributor(address(router));

        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;
        isTxLimitExempt[msg.sender] = true;
        isTxLimitExempt[address(this)] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[address(0xDead)] = true;

        autoLiquidityReceiver = m;
        marketingFeeReceiver = m;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function updateRouter(address _router) external onlyOwner {
        router = IDEXRouter(_router);
        pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));
    }

    function setLpPair(address _pair) external onlyOwner{
        lpPairs[_pair] = true;
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

    function allowance(address holder, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(
        address sender,
        address spender,
        uint256 amount
    ) private {
        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function limits(address from, address to) private view returns (bool) {
        return !isOwner(from)
            && !isOwner(to)
            && tx.origin != owner
            && !isAuthorized(from)
            && !isAuthorized(to)
            && to != address(0xdead)
            && to != address(0)
            && from != address(this);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (enableStaking) {
            require(
                _balances[sender] - amount >= stake.stakedTokens(sender),
                "Can not send staked token"
            );
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        if(limits(sender, recipient)){
            checkLaunched(sender);
            if(wenLaunch.launched){
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

        if(wenLaunch.launched){
            if(limits(sender, recipient)) {
                verifyUser(sender, recipient);
            }
        }

        _balances[sender] = _balances[sender] - amount;

        uint256 amountReceived = shouldTakeFee(sender)
            ? takeFee(sender, recipient, amount)
            : amount;
        _balances[recipient] = _balances[recipient] + amountReceived;

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

    function verifyUser(address from, address to) internal {
        require(!bannedUsers[to]);
        require(!bannedUsers[from]);
        if (wenLaunch.launchProtection) {
            if (lpPairs[from] && to != address(router) && !isFeeExempt[to]) {
                if (block.number <= wenLaunch.launchedAt + wenLaunch.antiBlocks) {
                    _setSniperStatus(to, true);
              }
            } else {
                wenLaunch.launchProtection = false;
            }
        }
        if (lpPairs[from] && to != address(router) && !isFeeExempt[to] && cooldownInfo.buycooldownEnabled) {
            require(buycooldown[to] < block.timestamp);
            buycooldown[to] = block.timestamp + (cooldownInfo.cooldown);
        } else if (!lpPairs[from] && !isFeeExempt[from] && cooldownInfo.sellcooldownEnabled){
                require(sellcooldown[from] <= block.timestamp);
                sellcooldown[from] = block.timestamp + (cooldownInfo.cooldown);
        } 
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function setSellMultiplier(uint256 SM) external authorized {
        require(SM <= maxSellMultiplier);
        sellMultiplier = SM;
    }

    function checkLaunched(address sender) internal view {
        require(wenLaunch.launched || isAuthorized(sender), "Pre-Launch Protection");
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= txSettings.maxTxAmount || isTxLimitExempt[sender],"TX Limit Exceeded");
    }

    function shouldTakeFee(address sender) internal view returns (bool) {
        return feeEnabled && !isFeeExempt[sender];
    }

    function takeFee(
        address sender,
        address receiver,
        uint256 amount
    ) internal returns (uint256) {
        if (isFeeExempt[sender] || isFeeExempt[receiver]) {
            return amount;
        }
        uint256 totalFee;
        if (lpPairs[receiver]) {
            if(sellMultiplier >= 1){
                totalFee = SellFees.totalFee * sellMultiplier;
            } else {
                totalFee = SellFees.totalFee;
            }
        } else if(lpPairs[sender]){
            totalFee = BuyFees.totalFee;
        } else {
            totalFee = TransferFees.totalFee;
        }

        if(block.number <= wenLaunch.launchedAt + sniperTaxBlocks){
            totalFee += 500; // Adds 50% tax onto original tax;
        }
        uint256 feeAmount = (amount * totalFee) / feeDenominator;

        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);

        if (lpPairs[receiver] && autoLiquifyEnabled) {
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
            !lpPairs[_msgSender()] &&
            !inSwap &&
            swapEnabled &&
            block.timestamp >= lastSwap + swapInterval &&
            _balances[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {
        lastSwap = block.timestamp;
        if (liquidityFeeAccumulator >= swapThreshold && autoLiquifyEnabled) {
            liquidityFeeAccumulator = liquidityFeeAccumulator - swapThreshold;
            uint256 amountForStaking = (swapThreshold * (BuyFees.stakeFee + SellFees.stakeFee) / (BuyFees.totalFee + SellFees.totalFee));
            _balances[stakingFeeReceiver] += amountForStaking;
            uint256 amountToLiquify = (swapThreshold - amountForStaking) / 2;

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

            uint256 amountBNB = address(this).balance - (balanceBefore);

            router.addLiquidityETH{value: amountBNB}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );

            emit AutoLiquify(amountBNB, amountToLiquify);
        } else {
            uint256 amountForStaking = (swapThreshold * (BuyFees.stakeFee + SellFees.stakeFee) / (BuyFees.totalFee + SellFees.totalFee));
            _balances[stakingFeeReceiver] += amountForStaking;
            uint256 amountToSwap = swapThreshold - amountForStaking;

            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

            uint256 balanceBefore = address(this).balance;

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToSwap,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 amountBNB = address(this).balance - (balanceBefore);

            uint256 amountBNBReflection = (amountBNB *
                (BuyFees.reflectionFee + SellFees.reflectionFee)) /
                (BuyFees.totalFee + SellFees.totalFee);
            uint256 amountBNBMarketing = (amountBNB *
                (BuyFees.marketingFee + SellFees.marketingFee)) /
                (BuyFees.totalFee + SellFees.totalFee);

            if(fundRewards){
                try distributor.deposit{value: amountBNBReflection}() {} catch {}
                (bool success, ) = payable(marketingFeeReceiver).call{
                value: amountBNBMarketing,
                gas: 30000
            }("");
            if (success) {
                marketingFees += amountBNBMarketing;
            }
            } else {
                payable(marketingFeeReceiver).transfer(amountBNBMarketing);
                marketingFees += amountBNBMarketing;
            }

            emit SwapBack(amountToSwap, amountBNB);
        }
    }

    function shouldAutoBuyback() internal view returns (bool) {
        return
            !lpPairs[_msgSender()] &&
            !inSwap &&
            autoBuybackEnabled &&
            autoBuybackBlockLast + autoBuybackBlockPeriod <= block.number &&
            address(this).balance >= autoBuybackAmount;
    }

    function buybackWEI(uint256 amount) external authorized {
        _buyback(amount);
    }

    function buybackBNB(uint256 amount) external authorized {
        _buyback(amount * (10**18));
    }

    function manualDeposit(uint256 amount) external onlyOwner {
        try distributor.deposit{value: amount}() {} catch {}
    }

    function _buyback(uint256 amount) internal {
        buyTokens(amount, stakingFeeReceiver);
        emit Buyback(amount);
    }

    function triggerAutoBuyback() internal {
        buyTokens(autoBuybackAmount, stakingFeeReceiver);
        autoBuybackBlockLast = block.number;
        autoBuybackAccumulator = autoBuybackAccumulator + autoBuybackAmount;
        if (autoBuybackAccumulator > autoBuybackCap) {
            autoBuybackEnabled = false;
        }
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(0, path, to, block.timestamp);
    }

    function setAutoBuybackSettings(
        bool _enabled,
        uint256 _cap,
        uint256 _amount,
        uint256 _period
    ) external authorized {
        autoBuybackEnabled = _enabled;
        autoBuybackCap = _cap;
        autoBuybackAccumulator = 0;
        autoBuybackAmount = _amount;
        autoBuybackBlockPeriod = _period;
        autoBuybackBlockLast = block.number;
        emit AutoBuybackSettingsUpdated(_enabled, _cap, _amount, _period);
    }

    function launch(uint256 blockAmount) public onlyOwner {
        require(blockAmount <= 5);
        require(wenLaunch.launched);
        swapEnabled = true;
        autoLiquifyEnabled = true;
        autoClaimEnabled = true;   
        wenLaunch.launchedAt = block.number;
        wenLaunch.antiBlocks = blockAmount;
        wenLaunch.launched = true;
        wenLaunch.launchProtection = true;
        setBuyFees(20, 10, 90, 30,10);
        setSellFees(20, 10, 90, 30,10);
        setTransferFees(10,10,10,10,10);
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

    function setIsDividendExempt(address holder, bool exempt)
        external
        authorized
    {
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

    function _setSniperStatus(address account, bool blacklisted) internal {
        if(lpPairs[account] || account == address(this) || account == address(router) || isFeeExempt[account]) {revert();}
        
        if (blacklisted == true) {
            bannedUsers[account] = true;
        } else {
            bannedUsers[account] = false;
        }    
    }
    
    function setWalletBanStatus(address user, bool banned) external onlyOwner {
        if (banned) {
            bannedUsers[user] = true;
        } else {
            delete bannedUsers[user];
        }
        emit WalletBanStatusUpdated(user, banned);
    }

    function setIsTxLimitExempt(address holder, bool exempt)
        external
        authorized
    {
        isTxLimitExempt[holder] = exempt;
        emit TxLimitExemptUpdated(holder, exempt);
    }

    function setBuyFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _stakeFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee && _stakeFee <= MaxFees.stakeFee);
        BuyFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            stakeFee: _stakeFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee + _stakeFee
        });
    }

    function FeesEnabled(bool _enabled) external onlyOwner {
        feeEnabled = _enabled;
        emit areFeesEnabled(_enabled);
    }

    function setSellFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _stakeFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee && _stakeFee <= MaxFees.stakeFee);
        SellFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            stakeFee: _stakeFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee + _stakeFee
        });
    }

    function setTransferFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _stakeFee) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee && _stakeFee <= MaxFees.stakeFee);
        TransferFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            stakeFee: _stakeFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee
        });
    }

    function decreaseMaxFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _stakeFee, bool resetFees) public authorized {
        require(_liquidityFee <= MaxFees.liquidityFee && _reflectionFee <= MaxFees.reflectionFee && _marketingFee <= MaxFees.marketingFee && _buybackFee <= MaxFees.buybackFee && _stakeFee <= MaxFees.stakeFee);
        MaxFees = IFees({
            liquidityFee: _liquidityFee,
            buybackFee: _buybackFee,
            reflectionFee: _reflectionFee,
            marketingFee: _marketingFee,
            stakeFee: _stakeFee,
            totalFee: _liquidityFee + _buybackFee + _reflectionFee + _marketingFee + _stakeFee
        });
        if(resetFees){
            setBuyFees(_liquidityFee, _buybackFee, _reflectionFee, _marketingFee, _stakeFee);
            setSellFees(_liquidityFee, _buybackFee, _reflectionFee, _marketingFee, _stakeFee);
        }
    }

    function setFeeReceivers(
        address _autoLiquidityReceiver,
        address _marketingFeeReceiver,
        address _stakingFeeReceiver
    ) external onlyOwner {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        marketingFeeReceiver = _marketingFeeReceiver;
        stakingFeeReceiver = _stakingFeeReceiver;
        emit FeeReceiversUpdated(_autoLiquidityReceiver, _marketingFeeReceiver, _stakingFeeReceiver);
    }

    function setCooldownEnabled(
        bool buy,
        bool sell,
        uint256 _cooldown
    ) external authorized {
        require(_cooldown <= cooldownInfo.cooldownLimit);
        cooldownInfo.cooldown = _cooldown;
        cooldownInfo.buycooldownEnabled = buy;
        cooldownInfo.sellcooldownEnabled = sell;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount)
        external
        authorized
    {
        swapEnabled = _enabled;
        swapThreshold = (_totalSupply * (_amount)) / (10000);
        emit SwapBackSettingsUpdated(_enabled, _amount);
    }

    function setAutoLiquifyEnabled(bool _enabled) external authorized {
        autoLiquifyEnabled = _enabled;
        emit AutoLiquifyUpdated(_enabled);
    }

    function setDistributionCriteria(
        uint256 _minPeriod,
        uint256 _minDistribution,
        uint256 _minHoldReq
    ) external authorized {
        distributor.setDistributionCriteria(
            _minPeriod,
            _minDistribution,
            _minHoldReq
        );
    }

    function setDistributorSettings(uint256 gas, bool _autoClaim)
        external
        authorized
    {
        require(gas <= 1000000);
        distributorGas = gas;
        autoClaimEnabled = _autoClaim;
        emit DistributorSettingsUpdated(gas, _autoClaim);
    }

    function getAccumulatedFees() external view returns (uint256) {
        return marketingFees;
    }

    function getAutoBuybackSettings()
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            autoBuybackEnabled,
            autoBuybackCap,
            autoBuybackAccumulator,
            autoBuybackAmount,
            autoBuybackBlockPeriod,
            autoBuybackBlockLast
        );
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
        uint256 _contractBalance = IBEP20(_token).balanceOf(address(this));
        _sent = IBEP20(_token).transfer(_to, _contractBalance);
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
    event Launch();
    event AutoLiquify(uint256 amountBNB, uint256 amountToken);
    event SwapBack(uint256 amountToken, uint256 amountBNB);
    event Buyback(uint256 amountBNB);
    event AutoBuybackSettingsUpdated(
        bool enabled,
        uint256 cap,
        uint256 amount,
        uint256 period
    );
    event TxLimitUpdated(uint256 amount);
    event DividendExemptUpdated(address holder, bool exempt);
    event FeeExemptUpdated(address holder, bool exempt);
    event TxLimitExemptUpdated(address holder, bool exempt);
    event FeeReceiversUpdated(
        address autoLiquidityReceiver,
        address marketingFeeReceiver,
        address stakingFeeReceiver
    );
    event SwapBackSettingsUpdated(bool enabled, uint256 amount);
    event areFeesEnabled(bool _enabled);
    event AutoLiquifyUpdated(bool enabled);
    event DistributorSettingsUpdated(uint256 gas, bool autoClaim);
    event WalletBanStatusUpdated(address user, bool banned);
}
