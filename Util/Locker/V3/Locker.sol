// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./IBEP20.sol";
import "./Lock.sol";
import "./ILocker.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapFactory.sol";

contract Locker is Ownable, ReentrancyGuard {

    struct Items {
        address lpToken;
        address withdrawalAddress;
        uint256 initialAmount;
        uint256 tokenAmount;
        uint256 dateLocked;
        uint256 unlockTime;
        bool withdrawn;
    }
    uint256 public bnbFee = .25 ether;
    uint256 public extendFee = 0.05 ether;
    uint256 public lpFeePercent = 5; // .5%
    uint256 public totalBnbFees;
    uint256 public remainingBnbFees;
    address[] tokenAddressesWithFees;
    mapping(address => uint256) public tokensFees;

    uint256 public depositId;
    uint256[] public allDepositIds;

    mapping(uint256 => Items) public lockedToken;
    mapping(uint256 => mapping(address => Lock)) public lpLockers;
    mapping(address => uint256[]) public depositsByWithdrawalAddress;
    mapping(address => uint256[]) public depositsByTokenAddress;

    IUniFactory public uniswapFactory;
    
    event lockOwnerShipTransferred(address indexed oldOwner, address indexed newOwner, uint256 id);
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime, uint256 depositId);
    event TokensWithdrawn(address indexed lpAddress, address indexed receiver);
    event LockExtended(uint256 NewLockTime, uint256 id, address indexed lpAddress);
    event lockAmountIncreased(uint256 id, address indexed lpAddress, uint256 amount);

    constructor() {
    }

    function getAllDepositIds() view public returns (uint256[] memory){
        return allDepositIds;
    }

    function getDepositDetails(uint256 _id) view public returns (address, address, uint256, uint256, uint256, bool){
        return (lockedToken[_id].lpToken, lockedToken[_id].withdrawalAddress, lockedToken[_id].tokenAmount, lockedToken[_id].dateLocked,
        lockedToken[_id].unlockTime, lockedToken[_id].withdrawn);
    }

    function getDepositsByWithdrawalAddress(address _withdrawalAddress) view public returns (uint256[] memory){
        return depositsByWithdrawalAddress[_withdrawalAddress];
    }

    function getDepositsByTokenAddress(address _lpAddress) view public returns (uint256[] memory){
        return depositsByTokenAddress[_lpAddress];
    }

    function getUnlockTime(uint256 _id) public view returns(uint256){
        return lpLockers[_id][lockedToken[_id].lpToken].getUnlockTime();   
    }

    function getTotalTokenBalance(uint256 _id) view public returns (uint256){
        return lpLockers[_id][lockedToken[_id].lpToken].getTotalTokenBalance();
    }

    function transferLockOwnership(address _lockOwner, uint256 _id) external {
        require(msg.sender == lockedToken[_id].withdrawalAddress);
        require(lpLockers[_id][lockedToken[_id].lpToken].transferLockOwnership(_lockOwner));
        lockedToken[_id].withdrawalAddress = _lockOwner;
        // Remove depositId from withdrawal addresses mapping
        uint256 i;
        uint256 j;
        uint256 byWLength = depositsByWithdrawalAddress[msg.sender].length;
        uint256[] memory newDepositsByWithdrawal = new uint256[](byWLength - 1);

        for (j = 0; j < byWLength; j++) {
            if (depositsByWithdrawalAddress[msg.sender][j] == _id) {
                for (i = j; i < byWLength - 1; i++) {
                    newDepositsByWithdrawal[i] = depositsByWithdrawalAddress[msg.sender][i + 1];
                }
                break;
            } else {
                newDepositsByWithdrawal[j] = depositsByWithdrawalAddress[msg.sender][j];
            }
        }
        depositsByWithdrawalAddress[msg.sender] = newDepositsByWithdrawal;


        depositsByWithdrawalAddress[_lockOwner].push(_id);
        emit lockOwnerShipTransferred(msg.sender, _lockOwner, _id);
    } 

    function increaseLockAmount(uint256 _id, uint256 _amount, bool _feeInBnb) external payable{
        require(_amount > 0, 'Tokens amount must be greater than 0');
        require(!lockedToken[_id].withdrawn);
        require(msg.sender == lockedToken[_id].withdrawalAddress, 'Only the locker owner can call this function');
        require(!_feeInBnb || msg.value > extendFee, 'BNB fee not provided');
        require(IBEP20(lockedToken[_id].lpToken).approve(address(lockedToken[_id].lpToken), _amount), 'Failed to approve tokens');
        require(IBEP20(lockedToken[_id].lpToken).transferFrom(msg.sender, address(lockedToken[_id].lpToken), _amount), 'Failed to transfer tokens to locker');
        require(lpLockers[_id][lockedToken[_id].lpToken].increaseLockAmount(_amount));
        lockedToken[_id].tokenAmount += _amount;
        totalBnbFees += msg.value;
        remainingBnbFees += msg.value;
        emit lockAmountIncreased(_id, lockedToken[_id].lpToken, _amount);
    }

    function extendLock(uint256 newLockTime, uint256 _id) external payable {
        require(newLockTime >= lpLockers[_id][lockedToken[_id].lpToken].getUnlockTime(), 'New lock time must be after unlockTime');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(msg.sender == lockedToken[_id].withdrawalAddress, 'Only the locked tokens withdrawal address can call this function');    
        require(newLockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(msg.value > extendFee, 'Must Provide BNB Fee');
        require(lpLockers[_id][lockedToken[_id].lpToken].extendLock(newLockTime));
        totalBnbFees += msg.value;
        remainingBnbFees += msg.value;
        lockedToken[_id].unlockTime = newLockTime;
        emit LockExtended(newLockTime, _id, lockedToken[_id].lpToken);
    }

    function lockTokens(
        address _lpToken,
        uint256 _amount,
        uint256 _unlockTime,
        bool _feeInBnb
    ) external payable returns (uint256 _id) {
        require(_amount > 0, 'Tokens amount must be greater than 0');
        require(_unlockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(_unlockTime > block.timestamp + 1 days, 'Unlock time must be after atleast 1 day');
        require(!_feeInBnb || msg.value > bnbFee, 'BNB fee not provided');
        IUniswapV2Pair lpair = IUniswapV2Pair(address(_lpToken));
        address factoryPairAddress = uniswapFactory.getPair(lpair.token0(), lpair.token1());
        require(factoryPairAddress == address(_lpToken), 'NOT UNIV2');

        uint256 lockAmount = _amount;
        if (_feeInBnb) {
            totalBnbFees += msg.value;
            remainingBnbFees += msg.value;
            lpLockers[_id][_lpToken] = new Lock(_lpToken, msg.sender, _amount, _unlockTime, _id);
            require(IBEP20(_lpToken).approve(address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_lpToken).transferFrom(msg.sender, address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to transfer tokens to locker');

            address _withdrawalAddress = msg.sender;
            _id = ++depositId;
            lockedToken[_id].lpToken = _lpToken;
            lockedToken[_id].withdrawalAddress = _withdrawalAddress;
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmount = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;
            lockedToken[_id].withdrawn = false;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_lpToken].push(_id);

            emit TokensLocked(_lpToken, msg.sender, _amount, _unlockTime, depositId);
        } else {
            uint256 fee = (lockAmount * lpFeePercent) / (1000);
            lockAmount -= fee;

            if (tokensFees[_lpToken] == 0) {
                tokenAddressesWithFees.push(_lpToken);
            }
            tokensFees[_lpToken] += fee;
            lpLockers[_id][_lpToken] = new Lock(_lpToken, msg.sender, _amount, _unlockTime, _id);
            require(IBEP20(_lpToken).approve(address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_lpToken).approve(address(this), fee), 'Failed to approve tokens');
            require(IBEP20(_lpToken).transferFrom(msg.sender, address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to transfer tokens to locker');
            require(IBEP20(_lpToken).transferFrom(msg.sender, address(this), fee), 'Failed to transfer fee to locker');

            address _withdrawalAddress = msg.sender;
            _id = ++depositId;
            lockedToken[_id].lpToken = _lpToken;
            lockedToken[_id].withdrawalAddress = _withdrawalAddress;            
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmount = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;
            lockedToken[_id].withdrawn = false;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_lpToken].push(_id);

            emit TokensLocked(_lpToken, msg.sender, _amount, _unlockTime, depositId);
        }
    }

    function withdrawTokens(uint256 _id) external {
        require(block.timestamp >= lpLockers[_id][lockedToken[_id].lpToken].getUnlockTime(), 'Tokens are locked');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(msg.sender == lockedToken[_id].withdrawalAddress, 'Can withdraw from the address used for locking');

        address tokenAddress = lockedToken[_id].lpToken;
        address withdrawalAddress = lockedToken[_id].withdrawalAddress;
        require(lpLockers[_id][lockedToken[_id].lpToken].withdrawTokens());
        lockedToken[_id].withdrawn = true;
        lockedToken[_id].tokenAmount -= lockedToken[_id].tokenAmount;
        // Remove depositId from withdrawal addresses mapping
        uint256 i;
        uint256 j;
        uint256 byWLength = depositsByWithdrawalAddress[withdrawalAddress].length;
        uint256[] memory newDepositsByWithdrawal = new uint256[](byWLength - 1);

        for (j = 0; j < byWLength; j++) {
            if (depositsByWithdrawalAddress[withdrawalAddress][j] == _id) {
                for (i = j; i < byWLength - 1; i++) {
                    newDepositsByWithdrawal[i] = depositsByWithdrawalAddress[withdrawalAddress][i + 1];
                }
                break;
            } else {
                newDepositsByWithdrawal[j] = depositsByWithdrawalAddress[withdrawalAddress][j];
            }
        }
        depositsByWithdrawalAddress[withdrawalAddress] = newDepositsByWithdrawal;

        // Remove depositId from tokens mapping
        uint256 byTLength = depositsByTokenAddress[tokenAddress].length;
        uint256[] memory newDepositsByToken = new uint256[](byTLength - 1);
        for (j = 0; j < byTLength; j++) {
            if (depositsByTokenAddress[tokenAddress][j] == _id) {
                for (i = j; i < byTLength - 1; i++) {
                    newDepositsByToken[i] = depositsByTokenAddress[tokenAddress][i + 1];
                }
                break;
            } else {
                newDepositsByToken[j] = depositsByTokenAddress[tokenAddress][j];
            }
        }
        depositsByTokenAddress[tokenAddress] = newDepositsByToken;

        emit TokensWithdrawn(tokenAddress, withdrawalAddress);
    }

    function setBnbFee(uint256 fee) external onlyOwner {
        require(fee > 0, 'Fee is too small');
        require(fee < 1 ether, 'Feee is too Large');
        bnbFee = fee;
    }

    function setLpFee(uint256 percent) external onlyOwner {
        require(percent > 0, 'Percent is too small');
        require(percent < 3, 'Percent is too Large');
        lpFeePercent = percent;
    }

    function setExtendFee(uint256 fee) external onlyOwner {
        require(fee > 0, 'Fee too small');
        require(fee < 0.25 ether, 'Fee is too Large');
        extendFee = fee;
    }

    function withdrawFees(address payable withdrawalAddress) external onlyOwner {
        if (remainingBnbFees > 0) {
            withdrawalAddress.transfer(remainingBnbFees);
            remainingBnbFees = 0;
        }

        for (uint i = 1; i <= tokenAddressesWithFees.length; i++) {
            address tokenAddress = tokenAddressesWithFees[tokenAddressesWithFees.length - i];
            uint256 amount = tokensFees[tokenAddress];
            if (amount > 0) {
                IBEP20(tokenAddress).transfer(withdrawalAddress, amount);
            }
            delete tokensFees[tokenAddress];
            tokenAddressesWithFees.pop();
        }

        tokenAddressesWithFees = new address[](0);
    }
}