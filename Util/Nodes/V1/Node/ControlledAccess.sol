// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./Ownable.sol";

contract ControlledAccess is Ownable {
    
    
   /* 
    * @dev Requires msg.sender to have valid access message.
    * @param _v ECDSA signature parameter v.
    * @param _r ECDSA signature parameters r.
    * @param _s ECDSA signature parameters s.
    */
    modifier onlyValidAccess(uint8 _v, bytes32 _r, bytes32 _s) 
    {
        require( isValidAccessMessage(msg.sender,_v,_r,_s), "Not valid Message");
        _;
    }
 
    /* 
    * @dev Verifies if message was signed by owner to give access to _add for this contract.
    *      Assumes Geth signature prefix.
    * @param _add Address of agent with access
    * @param _v ECDSA signature parameter v.
    * @param _r ECDSA signature parameters r.
    * @param _s ECDSA signature parameters s.
    * @return Validity of access message for a given address.
    */
    function isValidAccessMessage(
        address _add,
        uint8 _v, 
        bytes32 _r, 
        bytes32 _s

        ) 
        public view returns (bool)

    {
        bytes32 msgHash = keccak256(abi.encodePacked(address(this), _add));

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, msgHash));
                
        address _recovered = ecrecover(prefixedHash, _v, _r, _s);
        if (owner() == _recovered)
            {
                return true;
            }
            return false;
    }
}
