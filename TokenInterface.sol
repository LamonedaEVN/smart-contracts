pragma solidity ^0.4.25;

contract TokenInterface {
    function balanceOf(address _owner) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
}
