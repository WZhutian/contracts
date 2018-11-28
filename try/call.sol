pragma solidity  >=0.4.22 <0.6.0;
contract SimpleStorage {

    uint storedData;

    function set(uint x) public {
        storedData = x;    
    }
    function get() public  returns (uint) {
        return storedData;
    }
}

contract caller {
      
    function callData(address addr) public returns (uint){
        uint256 v = SimpleStorage(addr).get();
        return v;
    }
}