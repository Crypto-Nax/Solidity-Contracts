// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./IBEP20.sol";
import "./Lock.sol";
import "./ILocker.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapFactory.sol";
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC721Receiver.sol';

contract Locker is Ownable, ReentrancyGuard {

    struct Lockers {
        address lockOwner;
        address token;
        address withdrawalAddress;
        uint256 lockerId;
        uint256 initialAmount;
        uint256 tokenAmountOrId;
        uint256 dateLocked;
        uint256 unlockTime;
        bool withdrawn;
        bool lpToken;
        bool nft;
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

    mapping(uint256 => Lockers) public lockedToken;
    mapping(uint256 => mapping(address => Lock)) public lpLockers;
    mapping(address => uint256[]) public depositsByWithdrawalAddress;
    mapping(address => uint256[]) public depositsByTokenAddress;

    IUniFactory public uniswapFactory;
    
    event lockOwnerShipTransferred(address indexed oldOwner, address indexed newOwner, uint256 id);
    event TokensLocked(address indexed tokenAddress, address indexed sender, uint256 amount, uint256 unlockTime, uint256 depositId);
    event NftLocked(address indexed nftAddress, address indexed sender, uint256 tokenId, uint256 unlockTime, uint256 depositId);
    event TokensWithdrawn(address indexed tokenAddress, address indexed receiver);
    event LockExtended(uint256 NewLockTime, uint256 id, address indexed tokenAddress);
    event lockAmountIncreased(uint256 id, address indexed tokenAddress, uint256 amount);

    constructor() {
    }

    function getAllDepositIds() view public returns (uint256[] memory){
        return allDepositIds;
    }

    function getDepositDetails(uint256 _id) view public returns (address, address, address, uint256, uint256, uint256, bool){
        return (lockedToken[_id].lockOwner, lockedToken[_id].token, lockedToken[_id].withdrawalAddress, lockedToken[_id].tokenAmountOrId, lockedToken[_id].dateLocked,
        lockedToken[_id].unlockTime, lockedToken[_id].withdrawn);
    }

    function getDepositsByWithdrawalAddress(address _withdrawalAddress) view public returns (uint256[] memory){
        return depositsByWithdrawalAddress[_withdrawalAddress];
    }

    function getDepositsByTokenAddress(address _lpAddress) view public returns (uint256[] memory){
        return depositsByTokenAddress[_lpAddress];
    }

    function getUnlockTime(uint256 _id) public view returns(uint256){
        return lpLockers[_id][lockedToken[_id].token].getUnlockTime();   
    }

    function getTotalTokenBalance(uint256 _id) view public returns (uint256){
        return lpLockers[_id][lockedToken[_id].token].getTotalTokenBalance();
    }

    function transferLockOwnership(address _lockOwner, uint256 _id) external {
        require(msg.sender == lockedToken[_id].withdrawalAddress);
        require(lpLockers[_id][lockedToken[_id].token].transferLockOwnership(_lockOwner));
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
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(_msgSender() == lockedToken[_id].withdrawalAddress, 'Only the locker owner can call this function');
        require(!_feeInBnb || msg.value > extendFee, 'BNB fee not provided');
        if(_feeInBnb) {
            require(IBEP20(lockedToken[_id].token).approve(address(lockedToken[_id].token), _amount), 'Failed to approve tokens');
            require(IBEP20(lockedToken[_id].token).transferFrom(msg.sender, address(lockedToken[_id].token), _amount), 'Failed to transfer tokens to locker');
            require(lpLockers[_id][lockedToken[_id].token].increaseLockAmount(_amount));
            lockedToken[_id].tokenAmountOrId += _amount;
            totalBnbFees += msg.value;
            remainingBnbFees += msg.value;
            emit lockAmountIncreased(_id, lockedToken[_id].token, _amount);          
        } else {
            uint256 fee = (_amount * lpFeePercent) / (1000);
            _amount -= fee;            
            tokensFees[lockedToken[_id].token] += fee;
            require(IBEP20(lockedToken[_id].token).approve(address(lpLockers[_id][lockedToken[_id].token]), _amount), 'Failed to approve tokens');
            require(IBEP20(lockedToken[_id].token).approve(address(this), fee), 'Failed to approve tokens');
            require(IBEP20(lockedToken[_id].token).transferFrom(_msgSender(), address(lpLockers[_id][lockedToken[_id].token]), _amount), 'Failed to transfer tokens to locker');
            require(IBEP20(lockedToken[_id].token).transferFrom(_msgSender(), address(this), fee), 'Failed to transfer fee to locker');
        }
    }

    function depositOtherNft(uint256 tokenId, uint256 _id) external payable{
        require(msg.value > extendFee, 'BNB fee not provided');
        require(_msgSender() == lockedToken[_id].lockOwner);
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        IERC721 nftlock = IERC721(lockedToken[_id].token);
        nftlock.approve(address(this), tokenId);
        nftlock.safeTransferFrom(_msgSender(), address(this), tokenId);
        require(lpLockers[_id][address(nftlock)].depositOtherNft(tokenId));
    }

    function extendLock(uint256 newLockTime, uint256 _id) external payable {
        require(newLockTime >= lpLockers[_id][lockedToken[_id].token].getUnlockTime(), 'New lock time must be after unlockTime');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(_msgSender() == lockedToken[_id].withdrawalAddress, 'Only the locked tokens withdrawal address can call this function');    
        require(newLockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(msg.value > extendFee, 'Must Provide BNB Fee');
        require(lpLockers[_id][lockedToken[_id].token].extendLock(newLockTime));
        totalBnbFees += msg.value;
        remainingBnbFees += msg.value;
        lockedToken[_id].unlockTime = newLockTime;
        emit LockExtended(newLockTime, _id, lockedToken[_id].token);
    }

    function createLpLock(address _lpToken, uint256 _amount, uint256 _unlockTime, bool _feeInBnb, uint256 _id) internal returns(bool){
        IUniswapV2Pair lpPair = IUniswapV2Pair(address(_lpToken));
        address factoryPairAddress = uniswapFactory.getPair(lpPair.token0(), lpPair.token1());
        require(factoryPairAddress == address(_lpToken), 'NOT UNIV2');

        uint256 lockAmount = _amount;
        if (_feeInBnb) {

            address _withdrawalAddress = (_msgSender());
            _id = ++depositId;
            lpLockers[_id][_lpToken] = new Lock(_lpToken, _msgSender(), _amount, _unlockTime, _id, false);
            require(IBEP20(_lpToken).approve(address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_lpToken).transferFrom(_msgSender(), address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to transfer tokens to locker');

            lockedToken[_id].token = _lpToken;
            lockedToken[_id].lpToken = true;            
            lockedToken[_id].lockOwner = (_msgSender());
            lockedToken[_id].withdrawalAddress = (_msgSender());
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmountOrId = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;
            lockedToken[_id].withdrawn = false;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_lpToken].push(_id);
        } else {
            uint256 fee = (lockAmount * lpFeePercent) / (1000);
            lockAmount -= fee;

            if (tokensFees[_lpToken] == 0) {
                tokenAddressesWithFees.push(_lpToken);
            }
            _id = ++depositId;
            tokensFees[_lpToken] += fee;
            address _withdrawalAddress = (_msgSender());
            lpLockers[_id][_lpToken] = new Lock(_lpToken, msg.sender, _amount, _unlockTime, _id, false);
            require(IBEP20(_lpToken).approve(address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_lpToken).approve(address(this), fee), 'Failed to approve tokens');
            require(IBEP20(_lpToken).transferFrom(_msgSender(), address(lpLockers[_id][_lpToken]), lockAmount), 'Failed to transfer tokens to locker');
            require(IBEP20(_lpToken).transferFrom(_msgSender(), address(this), fee), 'Failed to transfer fee to locker');
            lockedToken[_id].token = _lpToken;
            lockedToken[_id].lpToken = true;
            lockedToken[_id].withdrawalAddress = (_msgSender());
            lockedToken[_id].lockOwner = (_msgSender());
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmountOrId = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_lpToken].push(_id);

        }
        return true;
    }

    function createNftLock(address nftAddress,uint256 _unlockTime, uint256 _id, uint256 tokenId) internal returns(bool){
        IERC721 nftlock = IERC721(nftAddress);
        _id = ++depositId;
        lpLockers[_id][nftAddress] = new Lock(nftAddress, _msgSender(), tokenId, _unlockTime,_id,true);
        nftlock.approve(address(lpLockers[_id][nftAddress]), tokenId);
        nftlock.safeTransferFrom(_msgSender(), address(lpLockers[_id][nftAddress]), tokenId);
        address _withdrawalAddress = msg.sender;
        lockedToken[_id].token = nftAddress;
        lockedToken[_id].nft = true;            
        lockedToken[_id].lockOwner = (_msgSender());
        lockedToken[_id].withdrawalAddress = _withdrawalAddress;
        lockedToken[_id].initialAmount = 1;
        lockedToken[_id].tokenAmountOrId = tokenId;
        lockedToken[_id].dateLocked = block.timestamp;
        lockedToken[_id].unlockTime = _unlockTime;
        allDepositIds.push(_id);
        depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
        depositsByTokenAddress[nftAddress].push(_id);    
        emit NftLocked(nftAddress, _msgSender(), tokenId, _unlockTime, _id);
        return true;
    }

    function createTokenLock(address _token, uint256 _amount, uint256 _unlockTime, bool _feeInBnb, uint256 _id) internal returns(bool){
        uint256 lockAmount = _amount;
        if (_feeInBnb) {
            address _withdrawalAddress = msg.sender;
            lpLockers[_id][_token] = new Lock(_token, _msgSender(), _amount, _unlockTime, _id, false);
            require(IBEP20(_token).approve(address(lpLockers[_id][_token]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_token).transferFrom(msg.sender, address(lpLockers[_id][_token]), lockAmount), 'Failed to transfer tokens to locker');

            lockedToken[_id].token = _token;            
            lockedToken[_id].lockOwner = (_msgSender());
            lockedToken[_id].withdrawalAddress = _withdrawalAddress;
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmountOrId = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_token].push(_id);

            emit TokensLocked(_token, _msgSender(), _amount, _unlockTime, depositId);
        } else {
            uint256 fee = (lockAmount * lpFeePercent) / (1000);
            lockAmount -= fee;

            if (tokensFees[_token] == 0) {
                tokenAddressesWithFees.push(_token);
            }

            address _withdrawalAddress = _msgSender();
            _id = ++depositId;

            tokensFees[_token] += fee;
            lpLockers[_id][_token] = new Lock(_token, msg.sender, _amount, _unlockTime, _id, false);
            require(IBEP20(_token).approve(address(lpLockers[_id][_token]), lockAmount), 'Failed to approve tokens');
            require(IBEP20(_token).approve(address(this), fee), 'Failed to approve tokens');
            require(IBEP20(_token).transferFrom(_msgSender(), address(lpLockers[_id][_token]), lockAmount), 'Failed to transfer tokens to locker');
            require(IBEP20(_token).transferFrom(_msgSender(), address(this), fee), 'Failed to transfer fee to locker');

            lockedToken[_id].token = _token;
            lockedToken[_id].withdrawalAddress = _withdrawalAddress;            
            lockedToken[_id].initialAmount = lockAmount;
            lockedToken[_id].tokenAmountOrId = lockAmount;
            lockedToken[_id].dateLocked = block.timestamp;
            lockedToken[_id].unlockTime = _unlockTime;
            lockedToken[_id].withdrawn = false;

            allDepositIds.push(_id);
            depositsByWithdrawalAddress[_withdrawalAddress].push(_id);
            depositsByTokenAddress[_token].push(_id);
        }
        return true;
    }

    function lockTokens(
        address _token,
        uint256 _amount,
        uint256 _unlockTime,
        uint256 _tokenId,
        bool _feeInBnb,
        bool isLp,
        bool isNFT
    ) external payable returns (uint256 _id) {
        if(!isNFT){require(_tokenId == 0);}
        if(isLp){require(isLp != isNFT);} else if(isNFT){require(isNFT != isLp && _feeInBnb);}
        require(_amount > 0, 'Tokens amount must be greater than 0');
        require(_unlockTime < 10000000000, 'Unix timestamp must be in seconds, not milliseconds');
        require(_unlockTime > block.timestamp + 1 days, 'Unlock time must be after atleast 1 day');
        if(isLp) {
            require(!_feeInBnb || msg.value > bnbFee, 'BNB fee not provided');
            if(_feeInBnb){totalBnbFees += msg.value; remainingBnbFees += msg.value;}
            _id = ++depositId;
            require(createLpLock(_token, _amount, _unlockTime, _feeInBnb, _id));
            emit TokensLocked(_token, msg.sender, _amount, _unlockTime, depositId);
        } else if(isNFT) {
            totalBnbFees += msg.value; 
            remainingBnbFees += msg.value;
            require(msg.value > bnbFee, 'BNB fee not provided');
            IERC721 nftlock = IERC721(_token);
            require(nftlock.ownerOf(_tokenId) == msg.sender);
            _id = ++depositId;
            require(createNftLock(_token, _unlockTime, _id, _tokenId));
        } else {        
            require(!_feeInBnb || msg.value > bnbFee, 'BNB fee not provided');
            if(_feeInBnb){totalBnbFees += msg.value; remainingBnbFees += msg.value;}
            _id = ++depositId;
            require(createTokenLock(_token, _amount, _unlockTime, _feeInBnb, _id));
            emit TokensLocked(_token, msg.sender, _amount, _unlockTime, depositId);
        }
    }

    function withdrawTokens(uint256 _id, address _withdrawalAddress) external {
        require(block.timestamp >= lpLockers[_id][lockedToken[_id].token].getUnlockTime(), 'Tokens are locked');
        require(!lockedToken[_id].withdrawn, 'Tokens already withdrawn');
        require(msg.sender == lockedToken[_id].withdrawalAddress, 'Can withdraw from the address used for locking');

        address tokenAddress = lockedToken[_id].token;
        address withdrawalAddress = lockedToken[_id].withdrawalAddress;
        require(lpLockers[_id][lockedToken[_id].token].withdrawTokens(_withdrawalAddress));
        lockedToken[_id].withdrawn = true;
        lockedToken[_id].tokenAmountOrId -= lockedToken[_id].tokenAmountOrId;
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