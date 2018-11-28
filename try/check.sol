pragma solidity  >=0.4.22 <0.6.0;
contract SimpleStorage {

    mapping(int => int) platInfo;  

    function set(int x) public {
        platInfo[x] = x;
    }
    
    function get(int x) public returns (int) {
        return platInfo[x];
    }
}
