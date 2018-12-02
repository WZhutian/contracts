pragma solidity ^0.4.11;
import "./TrustRule.sol";
import "./Register.sol";
import "./Tools.sol";
/* 联动规则合约 */
// 与用户场景合约流程类似， 只是平台需要有自己定义的规则  是否需要细化到属性层面
contract LinkageRule {

    // 联动控制记录
    struct Record{
        address linkPlatAddr;        //联动方平台地址
        address linkDeviceAddr;      //联动设备地址
        address controlPlatAddr;          //受控平台地址
        address controlDeviceAddr;        //受控设备地址
        string attrType;            //受控设备属性
        string attrState;           //受控设备状态
        uint ID;                  //记录ID
    }

    struct Attribute {
        string deviceType;
    }

    struct ControlledDevice {
        address deviceAddr;                                      // 控制设备地址
        address platformAddr;                                    // 控制平台地址
        uint attrNum;                                         // 可被控制属性总数
        mapping(string => Attribute) controllAttrs;             // 可被控制属性
    }

    struct LinkingDevice {
        address deviceAddr;                                      // 联动设备地址
        address platformAddr;                                    // 联动平台地址
        uint deviceNum;                                          // 控制的设备个数
        mapping(address => ControlledDevice) controllDevices;    // 用户设置的受控设备, key：受控设备地址
    }

    address platAddr;                                             // 定义此合约的平台链上地址
    uint linkingNums = 0;                                        // 联动规则总数(每一个属性的联动都算数)
    mapping(address => LinkingDevice) linkingRules;              // 联动规则表, key: 联动设备地址
    uint recordNums = 0;                                         // 联动记录总数
    mapping(uint => Record) linkingRecords;                   // 联动记录, key: 交易id
    address registerConstractAddr;                               // 注册合约地址

    /* 事件响应 */
    event addLinkageRuleEvent(address sender, bool result, string message);
    event linkageRuleEvent(address sender, bool result, string message);
    
    /* 构造函数 */
    function LinkageRule(address consAddr) public{
        platAddr = msg.sender;
        registerConstractAddr = consAddr;
    }


    /* 设置联动规则 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性
    function addLinkageRule(address[4] addr4, string attrType) 
        external returns(bool) {
        // 平台与设备是否注册
        if(checker(addr4)){
            addLinkageRuleEvent(msg.sender, false, "添加用户场景失败,平台或设备未注册");
            return false;
        }
        LinkingDevice storage linkingDevice = linkingRules[addr4[1]];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[addr4[3]];
        Attribute storage attribute = controlledDevice.controllAttrs[attrType];
        linkingDevice.deviceAddr = addr4[0];
        linkingDevice.platformAddr = addr4[1];
        linkingDevice.deviceNum++;
        controlledDevice.deviceAddr = addr4[3];
        controlledDevice.platformAddr = addr4[2];
        attribute.deviceType = attrType;
        controlledDevice.attrNum++;
        linkingNums++;
        addLinkageRuleEvent(msg.sender, true, "添加联动规则成功");
        return true;
    }

    /* 查询联动规则是否正确 */
    // 参数: 
    function checkLinkageRule(address[4] addr4, string attrType) constant public returns(bool){
        LinkingDevice storage linkingDevice = linkingRules[addr4[1]];
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

    TrustRule trustRule;
    /* 执行联动规则 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性,控制状态,信任规则合约地址
    function linkageRule(address[4] addr4, string attrType, string attrState, address trustAddr)
        external returns(bool) {
            
        // 调用注册合约，查询受控平台和设备是否注册
        if(!checker(addr4)){
            linkageRuleEvent(msg.sender, false, "受控平台和设备未注册");
            return false;
        }
        // 查询联动规则是否匹配
        if(!checkLinkageRule(addr4, attrType)){
            linkageRuleEvent(msg.sender, false, "联动规则不匹配");
            return false;
        }

        // 调用受控平台信任规则,检查是否能够联动
        trustRule = TrustRule(trustAddr);
        bool result = trustRule.trustRuleJudge(addr4[2],addr4[3]);
        if(!result){
            linkageRuleEvent(msg.sender, false, "未达到受控平台信任值");
            return false;
        }

        // 联动方的联动规则执行,记录联动结果
        recordLink(addr4, attrType, attrState);
        linkageRuleEvent(msg.sender, true, "联动成功");
        return true;
    }

    /* 检测平台和设备注册 */
    function checker(address[4] addr4) constant internal returns(bool){
        if(Register(registerConstractAddr).checkPlatformRegister(addr4[0]) 
            && Register(registerConstractAddr).checkDeviceRegister(addr4[0],addr4[1]) 
            && Register(registerConstractAddr).checkPlatformRegister(addr4[2]) 
            && Register(registerConstractAddr).checkDeviceRegister(addr4[2],addr4[3])){
            return true;
        }
        return false;
    }
    
    /* 记录联动控制 */
    function recordLink(address[4] addr4, string attrType, string attrState) internal returns(bool){
        Record storage record = linkingRecords[recordNums];
        record.linkPlatAddr = addr4[0];
        record.linkDeviceAddr = addr4[1];
        record.controlPlatAddr = addr4[2]; 
        record.controlDeviceAddr = addr4[3];
        record.attrType = attrType; 
        record.attrState = attrState;
        record.ID = recordNums;
        recordNums++;
        return true;
    }


    /* 查询联动控制记录 */
    function queryRecord(uint recordID) constant external returns(address, address, address, address, string, string, uint){
        Record storage record = linkingRecords[recordID];
        return (
            record.linkPlatAddr,
            record.linkDeviceAddr,
            record.controlPlatAddr, 
            record.controlDeviceAddr,
            record.attrType,           
            record.attrState, 
            record.ID
        );
    }
}
