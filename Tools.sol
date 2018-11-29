pragma solidity ^0.4.11;

/* 工具库 */
library Tools{
    // 字符串对比
    function equals(string a,string b) public returns(bool){
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        for (uint i = 0; i < bytes(a).length; ++i) {
            if (bytes(a)[i] != bytes(b)[i]) {
                return false;
            }
        }
        return true;
    }
}