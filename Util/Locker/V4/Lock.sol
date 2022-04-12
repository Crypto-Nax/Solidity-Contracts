// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./IBEP20.sol";
import "./ILocker.sol";
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC721Receiver.sol';

contract Lock is ReentrancyGuard, ILocker {
    struct tokenInfo{
        IBEP20 token;
        uint256 initalTokenAmount;
        uint256 tokenAmount;
    }

    struct nftInfo{
        IERC721 nftAddress;
        uint256 nftAmount;
        uint256 tokenId;
    }
    nftInfo public _nftInfo;
    tokenInfo public _tokenInfo;
    // address public token;
    address public lockOwner;
    address public mainLocker;
    // uint256 public initalTokenAmount;
    // uint256 public tokenAmount;
    uint256 public dateLocked;
    uint256 public unlockTime;
    uint256 public withdrawalTime;
    uint256 public Id;
    bool public withdrawn;
    bool public nftLocker;

    mapping(address => mapping(address => uint256)) public walletTokenBalance;

    modifier onlyLocker() {
        require(msg.sender == mainLocker); _;
    }

    constructor(address _token, address _lockOwner, uint256 amount, uint256 _unlockTime, uint256 _id, bool isNFT) payable {
        if(isNFT){
            mainLocker = address(0x0);
            _nftInfo.tokenId = amount;
            _nftInfo.nftAddress = IERC721(_token);
            lockOwner = _lockOwner;
            _nftInfo.nftAmount = 1;
            Id = _id;
            nftLocker = isNFT;
            dateLocked = block.timestamp;
            unlockTime = _unlockTime;
            walletTokenBalance[_token][_lockOwner] += amount;
        }  else {

            mainLocker = address(0x0);
            _tokenInfo.token = IBEP20(_token);
            lockOwner = _lockOwner;
            _tokenInfo.initalTokenAmount = amount;
            Id = _id;
            nftLocker = isNFT;
            _tokenInfo.tokenAmount = _tokenInfo.initalTokenAmount;
            dateLocked = block.timestamp;
            unlockTime = _unlockTime;
            walletTokenBalance[address(_tokenInfo.token)][_lockOwner] += amount;
        }
    }

    function getWithdrawalTime() external override view returns(uint256) {
        if(unlockTime >= block.timestamp) {
            return block.timestamp - unlockTime;
        } else {
            return unlockTime - block.timestamp;

        }
    }

    function getId() external override view returns(uint256) {
        return Id;
    }

    function getTotalTokenBalance() public override view returns (uint256){
        return _tokenInfo.tokenAmount;
    }

    function getTokenAddress() external override view returns(address){
        return address(_tokenInfo.token);
    }

    function getUnlockTime() external view override returns(uint256) {
        return unlockTime;
    }
    
    function increaseLockAmount(uint256 amount) external override onlyLocker returns(bool increased){
        require(!nftLocker);
        _tokenInfo.tokenAmount += amount;
        walletTokenBalance[address(_tokenInfo.token)][lockOwner] += _tokenInfo.tokenAmount;
        increased = true;
        return increased;
    }

    function transferLockOwnership(address _lockOwner) external override onlyLocker returns(bool transferred){
        if(!nftLocker){
            uint256 previousBalance = walletTokenBalance[address(_tokenInfo.token)][lockOwner];
            walletTokenBalance[address(_tokenInfo.token)][lockOwner] = previousBalance - _tokenInfo.tokenAmount;        
            walletTokenBalance[address(_tokenInfo.token)][_lockOwner] += _tokenInfo.tokenAmount;
            lockOwner = _lockOwner;
            transferred = true;
            return transferred;
        } else {
            lockOwner = _lockOwner;
            return transferred;
        }
    }

    function extendLock(uint256 newUnlockTime) external override onlyLocker returns(bool extended) {
        require(!withdrawn, 'Tokens already withdrawn');
        unlockTime = newUnlockTime;
        extended = true;
        return extended;
    }

    function withdrawTokens(address wAddress) external override onlyLocker returns(bool _withdrawn){
        if(!nftLocker){  
            if(wAddress == address(0)) {
                require(_tokenInfo.token.transfer(lockOwner, _tokenInfo.tokenAmount), 'Failed to transfer tokens');
                uint256 previousBalance = walletTokenBalance[address(_tokenInfo.token)][lockOwner];
                walletTokenBalance[address(_tokenInfo.token)][lockOwner] = previousBalance - _tokenInfo.tokenAmount;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
                return _withdrawn;
            } else {
                require(IBEP20(_tokenInfo.token).transfer(wAddress, _tokenInfo.tokenAmount), 'Failed to transfer tokens');
                uint256 previousBalance = walletTokenBalance[address(_tokenInfo.token)][lockOwner];
                walletTokenBalance[address(_tokenInfo.token)][lockOwner] = previousBalance - _tokenInfo.tokenAmount;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
                return _withdrawn;
            }
        }else{
            if(wAddress == address(0)) {
                _nftInfo.nftAddress.safeTransferFrom(address(this), lockOwner, _nftInfo.tokenId);
                _nftInfo.nftAmount -= _nftInfo.nftAmount;
                _nftInfo.tokenId -= _nftInfo.tokenId;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
                return _withdrawn;
            }
        }
    }
}