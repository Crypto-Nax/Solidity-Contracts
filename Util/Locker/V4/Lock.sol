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
        uint256[] tokenId;
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
            _nftInfo.tokenId.push(amount);
            _nftInfo.nftAddress = IERC721(_token);
            lockOwner = _lockOwner;
            _nftInfo.nftAmount = 1;
            Id = _id;
            nftLocker = isNFT;
            dateLocked = block.timestamp;
            unlockTime = _unlockTime;
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

    function getNftAddress() public override view returns(address) {
        return address(_nftInfo.nftAddress);
    }

    function getUnlockTime() external view override returns(uint256) {
        return unlockTime;
    }
    
    function depositOtherNft(uint256 tokenId) external override onlyLocker returns(bool increased) {
        require(nftLocker);
        IERC721 nftlock = IERC721(getNftAddress());
        nftlock.approve(address(this), tokenId);
        nftlock.safeTransferFrom(msg.sender, address(this), tokenId);
        _nftInfo.tokenId.push(tokenId);
        _nftInfo.nftAmount + 1;
        increased = true;
    }

    function increaseLockAmount(uint256 amount) external override onlyLocker returns(bool increased){
        require(!nftLocker);
        _tokenInfo.tokenAmount += amount;
        walletTokenBalance[address(_tokenInfo.token)][lockOwner] += _tokenInfo.tokenAmount;
        increased = true;
    }

    function transferLockOwnership(address _lockOwner) external override onlyLocker returns(bool transferred){
        if(!nftLocker){
            uint256 previousBalance = walletTokenBalance[address(_tokenInfo.token)][lockOwner];
            walletTokenBalance[address(_tokenInfo.token)][lockOwner] = previousBalance - _tokenInfo.tokenAmount;        
            walletTokenBalance[address(_tokenInfo.token)][_lockOwner] += _tokenInfo.tokenAmount;
            lockOwner = _lockOwner;
            transferred = true;
        } else {
            lockOwner = _lockOwner;
            transferred = true;
        }
    }

    function extendLock(uint256 newUnlockTime) external override onlyLocker returns(bool extended) {
        require(!withdrawn, 'Tokens already withdrawn');
        unlockTime = newUnlockTime;
        extended = true;
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
            } else {
                require(IBEP20(_tokenInfo.token).transfer(wAddress, _tokenInfo.tokenAmount), 'Failed to transfer tokens');
                uint256 previousBalance = walletTokenBalance[address(_tokenInfo.token)][lockOwner];
                walletTokenBalance[address(_tokenInfo.token)][lockOwner] = previousBalance - _tokenInfo.tokenAmount;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
            }
        }else{
            if(wAddress == address(0)) {
                for(uint8 i = 0; i < _nftInfo.tokenId.length; i++){
                    _nftInfo.nftAddress.safeTransferFrom(address(this), lockOwner, _nftInfo.tokenId[i]);
                }
                _nftInfo.nftAmount -= _nftInfo.nftAmount;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
            } else {
                for(uint8 i = 0; i < _nftInfo.tokenId.length; i++){
                    _nftInfo.nftAddress.safeTransferFrom(address(this), wAddress, _nftInfo.tokenId[i]);
                }
                _nftInfo.nftAmount -= _nftInfo.nftAmount;
                withdrawn = true;
                _withdrawn = withdrawn;
                withdrawalTime = block.timestamp;
            }
        }
    }
}