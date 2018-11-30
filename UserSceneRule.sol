pragma solidity ^0.4.11;
import "./LinkageRule.sol";
import "./Register.sol";
import "./Tools.sol";
/* 用户场景规则合约 —— 用户通过平台定义，与用户一一对应 */
// 用户定义
contract UserSceneRule {

    struct Attribute {
        string deviceType;
    }

    struct ControlledDevice {
        address deviceAddr;                                      // 控制设备地址
        address platformAddr;                                    // 控制平台地址
        address trustAddr;                                      // 受控平台信任规则合约地址
        uint attrNum;                                            // 可被控制属性总数
        mapping(string => Attribute) controllAttrs;             // 可被控制属性
    }

    struct LinkingDevice {
        address deviceAddr;                                      // 联动设备地址
        address platformAddr;                                    // 联动平台地址
        address ruleAddr;                                        // 联动规则合约地址(由联动平台定义)
        uint deviceNum;                                          // 控制的设备个数
        mapping(address => ControlledDevice) controllDevices;    // 用户设置的受控设备, key：受控设备地址
    }


    address usrAddr;                                             // 定义此合约的用户链上地址
    uint linkingNums = 0;                                        // 联动规则总数(每一个属性的联动都算数)
    mapping(address => LinkingDevice) userRules;                 // 联动规则表, key: 联动设备地址
    address registerConstractAddr;                               // 注册合约地址

    /* 构造函数 */
    function UserSceneRule(address consAddr) public{
        usrAddr = msg.sender;
        registerConstractAddr = consAddr;
    }

    /* 添加用户场景 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性,联动规则合约地址,受控信任规则合约地址
    function addUserSceneRule(address[4] addr4, string attrType, address ruleAddr, address trustAddr) 
        external returns(bool) {
        //参数检查
        LinkingDevice storage linkingDevice = userRules[addr4[1]];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[addr4[3]];
        Attribute storage attribute = controlledDevice.controllAttrs[attrType];
        linkingDevice.platformAddr = addr4[0];
        linkingDevice.deviceAddr = addr4[1];
        linkingDevice.ruleAddr = ruleAddr;
        linkingDevice.deviceNum++;
        controlledDevice.platformAddr = addr4[2];
        controlledDevice.deviceAddr = addr4[3];
        controlledDevice.trustAddr = trustAddr;
        controlledDevice.attrNum++;
        attribute.deviceType = attrType;
        linkingNums++;
        return true;
    }

    /* 查询用户规则是否正确 */
    // 如果正确则返回联动规则合约地址和信任规则合约地址
    // 参数: 联动表编号
    function checkUserSceneRule(address[4] addr4, string attrType) constant public returns(bool){
        LinkingDevice storage linkingDevice = userRules[addr4[1]];
        if (linkingDevice.deviceAddr == address(0) || linkingDevice.deviceAddr == addr4[1]){
            // 联动设备不存在
            return false;
        }
        if (linkingDevice.platformAddr == addr4[0]){
            // 联动平台不匹配
            return false;
        }
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[addr4[3]];
        if (controlledDevice.deviceAddr == address(0) || controlledDevice.deviceAddr == addr4[3]){
            // 受控设备不存在
            return false;
        }
        if (controlledDevice.platformAddr == addr4[2]){
            // 受控平台不匹配
            return false;
        }
        Attribute storage attribute = controlledDevice.controllAttrs[attrType];
        if (bytes(attribute.deviceType).length == 0 || Tools.equals(attribute.deviceType, attrType)){
            // 受控属性不存在
            return false;
        }
        return true;
    }

    /* 获取所有用户定义规则 */
    // TODO 是否有必要?
    function getUserSceneRule() external returns(bool){
    }

    LinkageRule linkage;
    /* 执行用户场景规则 */
    // 参数: 联动平台地址, 联动设备地址, 受控平台地址, 受控设备地址, 控制属性, 控制状态
    function userSceneRule(address[4] addr4, string attrType, string attrState)
        external returns(bool) {
        // 调用注册合约，查询受控平台和设备是否注册
        if(!checker(addr4)){
            return false;
        }
        // 检查用户规则
        if(!checkUserSceneRule(addr4, attrType)){
            return false;
        }
        // 调用联动规则合约
        LinkingDevice storage linkingDevice = userRules[addr4[1]];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[addr4[3]];
        
        linkage = LinkageRule(linkingDevice.ruleAddr);
        bool result = linkage.linkageRule(addr4, attrType, attrState, controlledDevice.trustAddr);       
        if(!result){
            return false;
        }
        return true;
    }
    
    /* 检测平台和设备注册 */
    function checker(address[4] addr4) internal returns(bool){
        if(Register(registerConstractAddr).checkRegister(addr4[0],1,address(0)) 
            && Register(registerConstractAddr).checkRegister(addr4[0],2,addr4[1]) 
            && Register(registerConstractAddr).checkRegister(addr4[2],1,address(0)) 
            && Register(registerConstractAddr).checkRegister(addr4[2],2,addr4[3])){
            return true;
        }
        return false;
    }
}
