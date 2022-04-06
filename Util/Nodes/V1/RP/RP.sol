//SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;
import "./IERC20.sol";
import "./Address.sol";
import "./IUniswapV2Router02.sol";
import "./Ownable.sol";

contract rewardPool is Ownable {
    struct NftData{
        address owner;
        uint256 lastClaim;
        uint256 creationTime;
    }

    uint256 public rewardRate;
    IUniswapV2Router02 public uniswapV2Router;
    mapping (uint => NftData) public nftInfo;
    uint public totalNodes = 0;

    constructor(address t) {     
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        Token = t;
    }
    
    receive() external payable {

  	}

    function addNodeInfo(uint _nftId, address _owner) external onlyNodes returns (bool success) {
        require(nftInfo[_nftId].owner == address(0), "Node already exists");
        
        nftInfo[_nftId].creationTime = block.timestamp;
        nftInfo[_nftId].owner = _owner;
        nftInfo[_nftId].lastClaim = block.timestamp;
        totalNodes += 1;
        return true;
    }

    function updateNodeOwner(uint _nftId, address _owner) external onlyNodes returns (bool success) {
        require(nftInfo[_nftId].owner != address(0), "Node does not exist");
        nftInfo[_nftId].owner = _owner;
        return true;
    }

    function updateRewardRates(uint256 _rewardRates) external onlyOwner {
        for (uint i = 1; i < totalNodes; i++) {
            claimReward(i);
        }
        rewardRate = _rewardRates;
    }    

    function pendingRewardFor(uint _nftId) public view returns (uint256 _reward) {
        uint _lastClaim = nftInfo[_nftId].lastClaim;
        uint _daysSinceLastClaim = ((block.timestamp - _lastClaim) * (1e9)) / 86400;
        _reward = (_daysSinceLastClaim * rewardRate) / (1e9);
        return _reward;
    }

    function claimReward(uint _nftId) public returns (bool success) {
        uint _reward = pendingRewardFor(_nftId);
        nftInfo[_nftId].lastClaim = block.timestamp;
        IERC20(Token).transfer(nftInfo[_nftId].owner, _reward);
        return true;
    }

}