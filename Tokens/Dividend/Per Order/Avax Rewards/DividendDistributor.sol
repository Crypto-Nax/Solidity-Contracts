//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
import "./IERC20.sol";
import "./SafeMath.sol";
import "./IJoeRouter02.sol";
import "./IDividendDistributor.sol";
import "./Context.sol";

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;
    address _token;
    
    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }
    
    IJoeRouter02 router;
    
    address[] shareholders;
    mapping (address => uint256) public shareholderIndexes;
    mapping (address => uint256) public shareholderClaims;
    mapping (address => Share) public shares;
    
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    
    uint256 public minPeriod = 1 days; // amount of time for min distribution to accumalate, once over it sends after x amount automatically.
    uint256 public minHoldAmount = 100 * (10**9); // 100 tokens for Avax rewards
    uint256 public minDistribution = 0.1 * (10 ** 18); // .1 Avax for auto claim
    uint256 public balance;
    
    uint256 currentIndex;
    

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }
    
    modifier updateBalance() {
        balance = address(this).balance; _;
    }
    modifier onlyToken() {
        require(msg.sender == _token); _;
    }
    
    constructor (address _router) {
        _token = msg.sender;
        router = IJoeRouter02(_router);
    }

    function updateDividendDistributor(address token, address _router) public override onlyToken {
        _token = token;
        router = IJoeRouter02(_router);
    }

    function getShareholderInfo(address shareholder) external view override returns (uint256, uint256, uint256, uint256) {
        return (
            totalShares,
            totalDistributed,
            shares[shareholder].amount,
            shares[shareholder].totalRealised       
        );
    }

    function holdAmount() external view override returns(uint256) {
        return minHoldAmount;
    }

    function getAccountInfo(address shareholder) external view override returns(uint256 pendingReward, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsUntilAutoClaimAvailable){
        pendingReward = getUnpaidEarnings(shareholder);
        lastClaimTime = shareholderClaims[shareholder];
        nextClaimTime = lastClaimTime + minPeriod;
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ? nextClaimTime.sub(block.timestamp) : 0;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution, uint256 _minHoldAmount) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution * (10**18);
        minHoldAmount = _minHoldAmount * (10**9);
        emit DistributionCriteriaUpdated(minPeriod, minDistribution, minHoldAmount);
    }
    
    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
        distributeDividend(shareholder);
            }
    
        if(amount > minHoldAmount && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount <= minHoldAmount && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }
    
        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
            
        emit ShareUpdated(shareholder, amount);
    }
    
    function deposit() external payable override updateBalance{
        
        uint256 amount = address(this).balance - balance;
    
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
        
    event DistributionCriteriaUpdated(uint256 minPeriod, uint256 minDistribution, uint256 minHoldAmount);
    event ShareUpdated(address shareholder, uint256 amount);
    event Deposit(uint256 amount);
    event Distribution(address shareholder, uint256 amount);
    event DividendsProcessed(uint256 iterations, uint256 count, uint256 index);
}