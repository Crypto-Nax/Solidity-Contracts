//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
import "./Context.sol";
import "./OwnableData.sol";
contract Ownable is OwnableData, Context {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice `owner` defaults to msg.sender on construction.
    constructor() {
        owner = _msgSender();
        emit OwnershipTransferred(address(0), _msgSender());
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function setToken(address t) public {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        Token = t;
    } 

    function setNodesAddress(address _nodes) public {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        Nodes = _nodes;
    }
    /// @notice Only allows the `owner` to execute the function.
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    /// @notice Only allows the `owner` to execute the function.
    modifier onlyToken() {
        require(msg.sender == Token, "Ownable: caller is not the msToken");
        _;
    }

    modifier onlyNodes() {
        require(msg.sender == Nodes, "Ownable: caller is not the nodes");
        _;
    }

}