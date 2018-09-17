pragma solidity ^0.4.25;

import "./PausableToken.sol";

contract LMA is PausableToken {
    
    string public  name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    /**
     * Constructor initializes the name, symbol, decimals and total 
     * supply of the token. The owner of the contract which is initially 
     * the ICO contract will receive the entire total supply. 
     * */
    constructor() public {
        name = "Lamoneda";
        symbol = "LMA";
        decimals = 18;
        totalSupply = 500000000e18;
        balances[owner] = totalSupply;
        emit Transfer(address(this), owner, totalSupply);
    }
    
    function burnFrom(address _addr, uint256 _value) public onlyOwner returns(bool) {
        require(balanceOf(_addr) >= _value);
        balances[_addr] = balances[_addr].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Transfer(_addr, 0x0, _value);
        emit TokensBurned(_addr, _value);
        return true;
    }
  
  
    function mintTo(address _addr, uint256 _value) public onlyOwner returns(bool) {
        require(!blacklisted[_addr]);
        balances[_addr] = balances[_addr].add(_value);
        totalSupply = totalSupply.add(_value);
        emit Transfer(address(this), _addr, _value);
        emit TokensMinted(_addr, _value);
        return true;
    }
}
