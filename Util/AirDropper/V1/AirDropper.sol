pragma solidity ^0.8.1;
// SPDX-License-Identifier: Unlicensed

import './Ownable.sol';
import './IERC20MetaData.sol';
contract AirDropper is Ownable {

    mapping(address => bool) public discountedAddress;
    mapping(address => uint256) public timesSent;
    uint256 public timesUsed;
    uint256 public tokenHoldReq;
    uint256 public tokenDiscount = 0.005 ether;
    uint256 public discountAmount = 0.000025 ether;
    uint256 public feeAmount = 0.025 ether;
    uint16 public airdropLimit = 200;
    IERC20 token;
    event totalAirdropped(uint256 total, address token);
    event tokensWithdrawn(address token, address owner, uint256 total);
    modifier airdropFees() {
        require(msg.value >= feeAmount - discountRate(msg.sender) || discountedAddress[msg.sender]);
        _;
    }

    constructor() {
        token = IERC20(address(0x0));
    }

    receive() external payable {}

    function setTokenHoldReq(uint256 amount) public onlyOwner {
        require(amount <= 100);
        tokenHoldReq = (token.totalSupply() * amount) / token.totalSupply();
    }

    function discountRate(address sender) public returns(uint256){
        if(token.balanceOf(sender) >= tokenHoldReq) {
            uint256 discountedAmount = tokenDiscount + (timesSent[sender] * discountAmount);
            if(discountAmount >= feeAmount){
                discountedAddress[sender] = true;
                return feeAmount;
            } else {
                return discountedAmount;
            }
        } else {
            uint256 discountedAmount = timesSent[sender] * discountAmount;
            if(discountedAmount >= feeAmount){
                discountedAddress[sender] = true;
                return feeAmount;
            } else {
                return discountedAmount;
            }
        }
    }

    function currentFee(address sender) public returns(uint256){
        return feeAmount - discountRate(sender);
    }

    function updateAirdropLimit(uint16 limit) external onlyOwner{
        airdropLimit = limit;
    }

    function updateFee(uint256 fees) external onlyOwner{
        require(fees <= 0.1 ether);
        feeAmount = fees;
    }

    function updateDiscountAmount(uint256 newDiscountAmount) external onlyOwner{
        discountAmount = newDiscountAmount;
    }

    function airdropTokens(address _token, uint256[] memory balances, address[] memory receivers) public airdropFees payable{
        require(receivers.length == balances.length, "Lengths do not match.");
        uint256 totalSent;
        require(receivers.length <= airdropLimit);
        IERC20 airdropToken = IERC20(_token);
        for(uint8 i = 0; i < receivers.length; i++){
            require(airdropToken.balanceOf(msg.sender) >= balances[i]);
            airdropToken.transferFrom(msg.sender, receivers[i], balances[i]);
            totalSent += balances[i];
        }
        timesSent[msg.sender]++;
        timesUsed++;
        emit totalAirdropped(totalSent, _token);
    }

    function airdropEth(uint256[] memory balances, address[] memory receivers) public airdropFees payable{
        require(receivers.length == balances.length, "Lengths do not match.");
        uint256 totalSent;
        require(receivers.length <= airdropLimit);
        for(uint8 i = 0; i < receivers.length; i++){
            payable(receivers[i]).transfer(balances[i]);
            totalSent += balances[i];
        }
        timesSent[msg.sender]++;
        timesUsed++;
        emit totalAirdropped(totalSent, address(0));
    }

    function clearStuckToken(address _token) external onlyOwner{
        if(_token == address(0)){
            uint256 amountEth = address(this).balance;
            payable(owner()).transfer(amountEth);
        }
        IERC20 stuckToken = IERC20(_token);
        uint256 balance = stuckToken.balanceOf(address(this));
        stuckToken.transfer(owner(), balance);
        emit tokensWithdrawn(_token, owner(), balance);
    }
}