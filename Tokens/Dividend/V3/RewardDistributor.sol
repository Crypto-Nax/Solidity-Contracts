//SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
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

    interface IBEP20 {
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
    
    interface IDEXRouter {
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
        function claimDividendAsFor(address shareholder) external;
        function getShareholderInfo(address shareholder) external view returns (uint256, uint256, uint256, uint256);
        function getAccountInfo(address shareholder) external view returns ( uint256, uint256, uint256, uint256);
    }

    contract DividendDistributor is IDividendDistributor {
        using SafeMath for uint256;
    
        address _token;
    
        struct Share {
            uint256 amount;
            uint256 totalExcluded;
            uint256 totalRealised;
        }
    
        IBEP20 RewardToken = IBEP20(0x0);
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        IDEXRouter router;
    
        address[] shareholders;
        mapping (address => uint256) shareholderIndexes;
        mapping (address => uint256) shareholderClaims;
        mapping (address => Share) public shares;
    
        uint256 public totalShares;
        uint256 public totalDividends;
        uint256 public totalDistributed;
        uint256 public dividendsPerShare;
        uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    
        uint256 public minPeriod = 120 minutes; // amount of time for min distribution to accumalate, once over it sends after x amount automatically.
        uint256 public minHoldReq = 100 * (10**9); // 100 tokens for busd rewards
        uint256 public minDistribution = 1 * (10 ** 18); // 1 token with 18 decimals reward for auto claim
    
    
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
    
        constructor () {
            _token = msg.sender;
            router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
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

        function getAccount(address shareholder) public view returns(
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
            uint256 balanceBefore = RewardToken.balanceOf(address(this));
    
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = address(RewardToken);
    
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
                0,
                path,
                address(this),
                block.timestamp
            );
    
            uint256 amount = RewardToken.balanceOf(address(this)).sub(balanceBefore);
    
            totalDividends = totalDividends.add(amount);
            dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
            
            emit Deposit(msg.value, amount);
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
                RewardToken.transfer(shareholder, amount);
                shareholderClaims[shareholder] = block.timestamp;
                shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
                shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
                
                emit Distribution(shareholder, amount);
            }
        }
    
        function distributeDividendAs(address shareholder) internal {
            if(shares[shareholder].amount == 0){ return; }
    
            uint256 amount = getUnpaidEarnings(shareholder);
            if(amount > 0){
                uint256 balanceBefore = address(this).balance;
                totalDistributed = totalDistributed.add(amount);
                shareholderClaims[shareholder] = block.timestamp;
                shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
                shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
                address[] memory path = new address[](2);
                path[0] = address(RewardToken);
                path[1] = WBNB;

                router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0,
                path,
                address(this),
                block.timestamp);
                uint256 amountPayout = address(this).balance - (balanceBefore);
                payable(shareholder).transfer(amountPayout);

                emit Distribution(shareholder, amount);
            }
        }

        function claimDividend() external {
            distributeDividend(msg.sender);
        }
    
        function claimDividendFor(address shareholder) external override {
            distributeDividend(shareholder);
        }

        function claimDividendAs() external {
            distributeDividendAs(msg.sender);
        }
    
        function claimDividendAsFor(address shareholder) external override {
            distributeDividendAs(shareholder);
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
        event Deposit(uint256 amountBNB, uint256 amountDOT);
        event Distribution(address shareholder, uint256 amount);
        event DividendsProcessed(uint256 iterations, uint256 count, uint256 index);
    }