pragma solidity ^0.4.11;
import "./UserSceneRule.sol";

/* 信任规则合约 —— 与平台一一对应 */
contract TrustRule {
    // 平台信任的设备
    struct Device {
        address addr;                        // 设备链上地址
        int trustValue;                           // 信任值
    }

    address registerConstractAddr;                 // 注册合约地址
    address platformAddr;                          // 定义此规则的平台的地址
    uint trustDeviceNum;                           // 平台信任设备个数
    mapping(address => Device) trustDevices;       // 平台信任的的可联动设备映射表, key：设备地址
    int trustThreshold;                           // 平台信任设备的信任阈值，(当前为统一信任值, 后期优化会针对设备类型不同)

    /* 事件响应 */
    event setTrustThresholdEvent(address sender, bool result, string message);
    event setDevicesEvent(address sender, bool result, string message);
    event TrustRuleEvent(address sender, bool result, string message);

    /* 构造函数 */
    function TrustRule(address consAddr) public{
        platformAddr = msg.sender;
        registerConstractAddr = consAddr;
    }
    
    /* 设置信任阈值 */
    // 参数: 信任值
    function setTrustThreshold(int value) external returns(bool){
        trustThreshold = value;
        setTrustThresholdEvent(msg.sender,true,"信任值设置成功");
        return true;
    }

    /* 添加/修改/删除信任设备 */
    // 参数: 设备地址, 信任值, 操作码(0:添加,1:修改,2:删除)
    function setDevices(address deviceAddr,int trustValue,uint8 opCode) external returns(bool){
        Device storage device = trustDevices[deviceAddr];   
        if(uint8(0) == opCode){
            device.addr = deviceAddr;
            device.trustValue = trustValue;
            trustDeviceNum++;
        }else if(uint8(1) == opCode){
            device.addr = deviceAddr;
            device.trustValue = trustValue;
        }else if(uint8(2) == opCode){
            delete trustDevices[deviceAddr];
        }else{
            setDevicesEvent(msg.sender,false,"未知操作符");
            return false; // 未知操作符
        }
        setDevicesEvent(msg.sender,true,"操作成功");
        return true;
    }

    /* 信任规则函数 */
    // 参数: 平台地址, 设备地址
    function trustRuleJudge(address platAddr, address deviceAddr) constant public returns(bool) {

        // 调用注册合约，查询平台是否注册，设备是否在平台注册
        if(!Register(registerConstractAddr).checkPlatformRegister(platAddr) ||
            !Register(registerConstractAddr).checkDeviceRegister(platAddr,deviceAddr)){
            return false;
        }

        // 获取信任合约自己的数据库入口
        Device storage device = trustDevices[deviceAddr];

        // 判断设备的信任值，是否大于平台在合约端预设的阈值
        return device.trustValue >= trustThreshold;     
    }

    UserSceneRule userScene;
    /* 联动步骤开始 (1.调用用户场景规则 2.再嵌套调用联动规则 3.调用受控平台信任规则 4.最后写入联动记录)*/
    // 用户参数输入:[联动平台地址,联动设备地址,受控平台地址,受控设备地址],控制属性,控制状态,用户规则合约
    function startLinking(address[4] addr4, string attrType, string attrState, address userRuleAddr) 
        external{
        if(trustRuleJudge(addr4[0],addr4[1])){// 调用信任值判断
            // 继续调用用户场景规则合约
            userScene = UserSceneRule(userRuleAddr);
            bool result = userScene.userSceneRule(addr4, attrType, attrState);
            TrustRuleEvent(msg.sender, result, "调用成功");
        }else{
            TrustRuleEvent(msg.sender, false, "信任值不够");
        }
    }
}