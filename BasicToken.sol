pragma solidity ^0.4.25;

import "./Ownable.sol";

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic, Ownable {
    
  using SafeMath for uint256;
  
  event TokensBurned(address from, uint256 value);
  event TokensMinted(address to, uint256 value);

  mapping(address => uint256) balances;
  mapping(address => bool) blacklisted;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }
  

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(!blacklisted[msg.sender] && !blacklisted[_to]);
    require(_to != address(0));
    require(_value <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }


  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
  }
  
  
  
  function addToBlacklist(address[] _addrs) public onlyOwner returns(bool) {
      for(uint i=0; i < _addrs.length; i++) {
          blacklisted[_addrs[i]] = true;
      }
      return true;
  }
  
  
  function removeFromBlacklist(address _addr) public onlyOwner returns(bool) {
      require(blacklisted[_addr]);
      blacklisted[_addr] = false;
      return true;
  }
  

}
