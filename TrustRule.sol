pragma solidity ^0.4.11;
import "./UserSceneRule.sol";
import "./Tools.sol";

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
            setDevicesEvent(msg.sender,true,"添加成功");
        }else if(uint8(1) == opCode){
            device.addr = deviceAddr;
            device.trustValue = trustValue;
            setDevicesEvent(msg.sender,true,"修改成功");
        }else if(uint8(2) == opCode){
            delete trustDevices[deviceAddr];
            setDevicesEvent(msg.sender,true,"删除成功");
        }else{
            setDevicesEvent(msg.sender,false,"未知操作符");
            return false; // 未知操作符
        }
        return true;
    }

    /* 信任规则函数 */
    // 参数: 平台地址, 设备地址 (由于需要跨合约调用,使用bytes32)
    function trustRuleJudge(address platAddr, address deviceAddr) constant public returns(bool, bytes32) {

        // 调用注册合约，查询平台是否注册，设备是否在平台注册
        if(!Register(registerConstractAddr).checkPlatformRegister(platAddr)){
            return (false,"平台未注册");
        }
        if(!Register(registerConstractAddr).checkDeviceRegister(platAddr,deviceAddr)){
            return (false,"设备未注册");
        }

        // 获取信任合约自己的数据库入口
        Device storage device = trustDevices[deviceAddr];

        // 判断设备的信任值，是否大于平台在合约端预设的阈值
        if((device.trustValue >= trustThreshold)){
            return (true,"设备可信任");
        }
        return (false,"未达到平台阈值");
    }

    UserSceneRule userScene;
    /* 联动步骤开始 (1.调用用户场景规则 2.再嵌套调用联动规则 3.调用受控平台信任规则 4.最后写入联动记录)*/
    // 用户参数输入:[联动平台地址,联动设备地址,受控平台地址,受控设备地址],控制属性,控制状态,用户规则合约
    function startLinking(address[4] addr4, string attrType, string attrState, address userRuleAddr) 
        external{
        bool judgeResult;
        bytes32 judgeMessage;
        (judgeResult,judgeMessage) = trustRuleJudge(addr4[0],addr4[1]);
        if(judgeResult){// 调用信任值判断
            // 继续调用用户场景规则合约
            userScene = UserSceneRule(userRuleAddr);
            bool result = userScene.userSceneRule(addr4, attrType, attrState);
            TrustRuleEvent(msg.sender, result, "调用成功");
        }else{
            TrustRuleEvent(msg.sender, false, bytes32ToStr(judgeMessage));
        }
    }
    
    /* 临时方法 */
    function bytes32ToStr(bytes32 _bytes32) private constant returns (string){
    // string memory str = string(_bytes32);
    // TypeError: Explicit type conversion not allowed from "bytes32" to "string storage pointer"
    // thus we should fist convert bytes32 to bytes (to dynamically-sized byte array)
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}