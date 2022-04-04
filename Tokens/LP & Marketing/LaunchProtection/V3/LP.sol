pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed
import "./IERC20.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./Verify.sol";
import "./Address.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";
import "./IERC20MetaData.sol";

contract R is Context, IERC20, Ownable, IERC20Metadata {
    using Address for address;

    string private _name = "----";
    string private _symbol = "---";
    uint8 private _decimals = 9;
    uint256 private _tTotal = 1_000_000_000 * 10**_decimals;
    address payable public _marketingWallet;

    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public _isExcludedFromFee;
    mapping(address => bool) lpPairs;

    uint256 public _liquidityFee;
    uint256 private _previousLiquidityFee = _liquidityFee;
    uint256 public _marketingFee;
    uint256 private _previousMarketingFee = _marketingFee;
    uint256 public _buyLiquidityFee;
    uint256 private _previousBuyLiquidityFee = _buyLiquidityFee;
    uint256 public _buyMarketingFee;
    uint256 private _previousBuyMarketingFee = _buyMarketingFee;
    uint256 numTokensToSwap;
    uint256 lastSwap;
    uint256 swapInterval = 30 seconds;

    Verify Verifier;
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    bool launched;
    bool limiter;
    bool public tradingEnabled;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        _tOwned[_msgSender()] = _tTotal;
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        lpPairs[uniswapV2Pair] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function start(address V, address payable m) external onlyOwner {
        setWallets(m);
        Verifier = Verify(V);
        excludeFromFee(owner());
        excludeFromFee(address(this));
        setLimits(true);
        Verifier.setLpPair(uniswapV2Pair, true);
        setSellFee(3,9);
        setBuyFee(9,3);
        setNumTokensToSwap(1,1000);
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function limitedTx(bool onoff) public onlyOwner {
        Verifier.limitedTx(onoff);
    }

    function setLpPair(address pair, bool enabled) external onlyOwner {
        lpPairs[pair] = enabled;
        Verifier.setLpPair(pair, enabled);
    }
    
    function getTxSetting() public view returns(uint256 maxTx, uint256 maxWallet, bool limited){
        return Verifier.getTxSetting();
    }

    function getCoolDownSettings() public view returns(bool buyCooldown, bool sellCooldown, uint256 coolDownTime, uint256 coolDownLimit) {
        return Verifier.getCoolDownSettings();
    }

    function getBlacklistStatus(address account) public view returns(bool) {
        return Verifier.getBlacklistStatus(account);
    }

    function setSellFee(uint256 liquidityFee, uint256 marketingFee) public onlyOwner {
        require(liquidityFee + marketingFee <= 20);
        _liquidityFee = liquidityFee;
        _marketingFee = marketingFee;
    }

    function setBuyFee(uint256 marketingFee, uint256 liquidityFee) public onlyOwner {
        require(liquidityFee + marketingFee <= 20);
        _buyMarketingFee = marketingFee;
        _buyLiquidityFee = liquidityFee;
    }

    function setWallets(address payable m) public onlyOwner {
        _marketingWallet = payable(m);
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool){
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + (addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - (subtractedValue)
        );
        return true;
    }

    function setLimits(bool onoff) public onlyOwner {
        limiter = onoff;
    }

    function setBlacklistStatus(address account, bool blacklisted) external onlyOwner {
        Verifier.setSniperStatus(account, blacklisted);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
        Verifier.feeExcluded(account, true);
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
        Verifier.feeExcluded(account, false);
    }

    function setNumTokensToSwap( uint256 percent, uint256 divisor) public onlyOwner {
        numTokensToSwap = (_tTotal * percent) / divisor;
    }
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    event SwapAndLiquifyEnabledUpdated(bool enabled);

    //to receive ETH from uniswapV2Router when swapping
    receive() external payable {}

    function removeAllFee() private {
        if (
            _liquidityFee == 0 &&
            _marketingFee == 0 &&
            _buyMarketingFee == 0 &&
            _buyLiquidityFee == 0
        ) return;
        _previousMarketingFee = _marketingFee;
        _previousLiquidityFee = _liquidityFee;
        _previousBuyMarketingFee = _buyMarketingFee;
        _previousBuyLiquidityFee = _buyLiquidityFee;
        _buyMarketingFee = 0;
        _buyLiquidityFee = 0;
        _marketingFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _marketingFee = _previousMarketingFee;
        _liquidityFee = _previousLiquidityFee;
        _buyLiquidityFee = _previousBuyLiquidityFee;
        _buyMarketingFee = _previousBuyMarketingFee;
    }

    function _approve(address owner,address spender,uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    event ToMarketing(uint256 marketingBalance);
    event SwapAndLiquify(
        uint256 liquidityTokens,
        uint256 liquidityFees
    );

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        lastSwap = block.timestamp;

        uint256 FeeDivisor = _buyLiquidityFee + _buyMarketingFee + _liquidityFee + _marketingFee;

        uint256 liquidityTokens = contractTokenBalance * ((_buyLiquidityFee + _liquidityFee) / FeeDivisor) / 2;
        uint256 tokensToSwap = contractTokenBalance - liquidityTokens;

        swapTokensForEth(tokensToSwap);

        uint256 initialBalance = address(this).balance;

        uint256 liquidityFees = (initialBalance * liquidityTokens) / tokensToSwap;

        addLiquidity(liquidityTokens, liquidityFees);

        emit SwapAndLiquify(liquidityTokens, liquidityFees);

        uint256 marketingBalance = initialBalance - liquidityFees;
        _marketingWallet.transfer(marketingBalance);
        emit ToMarketing(marketingBalance);
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        require(amountPercentage <= 100);
        uint256 amountETH = address(this).balance;
        payable(_marketingWallet).transfer(
            (amountETH * (amountPercentage)) / (100)
        );
    }

    function clearStuckToken(address to) external onlyOwner {
        uint256 _balance = balanceOf(address(this));
        _transfer(address(this), to, _balance);
    }

    function clearStuckTokens(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0));
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }

    function airDropTokens(address[] memory addresses, uint256[] memory amounts) external {
        require(addresses.length == amounts.length, "Lengths do not match.");
        for (uint8 i = 0; i < addresses.length; i++) {
            require(balanceOf(msg.sender) >= amounts[i]);
            _transfer(msg.sender, addresses[i], amounts[i]*10**_decimals);
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function transferFrom(address sender,address recipient,uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - (
                amount
            )
        );
        return true;
    }

    function limits(address from, address to) private view returns (bool) {
        return from != owner()
            && to != owner()
            && tx.origin != owner()
            && !lpPairs[to]
            && !lpPairs[from]
            && !_isExcludedFromFee[from]
            && !_isExcludedFromFee[to]
            && to != address(0x0dead)
            && to != address(0)
            && from != address(this);
    }

    function launch() internal {
        launched = true;
        swapAndLiquifyEnabled = true;
        Verifier.checkLaunch(block.number, true, true);
        tradingEnabled = true;
        setLimits(true);
        emit Launch();
    }

    event Launch();

    function shouldSwap() internal view returns(bool){
        return 
                !lpPairs[msg.sender] &&
                !inSwapAndLiquify &&
                swapAndLiquifyEnabled &&
                balanceOf(address(this)) >= numTokensToSwap &&
                block.timestamp >= lastSwap + swapInterval;

    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!launched && to == uniswapV2Pair) {
            require(from == owner() || _isExcludedFromFee[from]);
            launch();
        }
        if(limits(from, to)) {
            if(!tradingEnabled){
                revert();
            }
        }

        if (shouldSwap()) {swapAndLiquify(numTokensToSwap);}

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, marketing, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender,address recipient,uint256 amount,bool takeFee) private {
        if(limiter) {
            bool verified;
            try Verifier.verifyUser(sender, recipient, amount) returns (bool _verified) {
                verified = _verified;
            } catch {
                revert();
                } if(!verified) {
                    revert();
                }
            }

        if (!takeFee) {removeAllFee();}

        if (sender == uniswapV2Pair && recipient != address(uniswapV2Router)) {
            _transferStandardBuy(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) {restoreAllFee();}
    }

    function _transferStandardBuy(address sender,address recipient,uint256 amount) private {
        uint256 feeAmount = (amount * (_buyLiquidityFee + _buyMarketingFee)) / (100);
        uint256 tAmount = amount - feeAmount;
        _tOwned[sender] -= amount;
        _tOwned[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);
        _tOwned[recipient] += tAmount;
        emit Transfer(sender, recipient, tAmount);
    }

    function _transferStandard(address sender,address recipient,uint256 amount) private {
        uint256 feeAmount = (amount * (_liquidityFee + _marketingFee)) / (100);
        uint256 tAmount = amount - feeAmount;
        _tOwned[sender] -= amount;
        _tOwned[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);
        _tOwned[recipient] += tAmount;
        emit Transfer(sender, recipient, tAmount);
    }

}