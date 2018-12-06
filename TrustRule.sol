pragma solidity ^0.4.11;
import "./UserSceneRule.sol";

/* 信任规则合约 —— 与平台一一对应 */
contract TrustRule {
    // 平台信任的设备
    struct Device {
        address addr;                        // 设备链上地址
        int trustValue;                           // 信任值
    }
    
    struct Nounce {
        address addr;                           //请求者地址
        uint256 nounce;                          //请求者产生的随机值
        uint256 timeStamp;                      //时间戳
    }

    address registerConstractAddr;                 // 注册合约地址
    address platAddr;                          // 定义此规则的平台的地址
    uint trustDeviceNum;                           // 平台信任设备个数
    mapping(address => Device) trustDevices;       // 平台信任的的可联动设备映射表, key：设备地址
    int trustThreshold;                           // 平台信任设备的信任阈值，(当前为统一信任值, 后期优化会针对设备类型不同)
    mapping(address => Nounce) nounceList;       //nounce列表, key: 用户地址

    /* 事件响应 */
    event setTrustThresholdEvent(address sender, bool result, string message);
    event setDevicesEvent(address sender, bool result, string message);
    event TrustRuleEvent(address sender, bool result, string message);

    /* 构造函数 */
    // TODO 向Register合约验证,平台是否注册
    function TrustRule(address plat,address consAddr) public{
        platAddr = plat;
        registerConstractAddr = consAddr;
    }

    /* 获取定义该合约的平台地址 */
    // 用于鉴别联动控制过程中,请求确实是从本合约的startlink发起的
    function getPlatAddr() constant external returns(address){
        return platAddr;
    }
    
    /* 设置信任阈值 */
    // 参数: 信任值, 签名, nounce与时间戳
    function setTrustThreshold(int value,bytes32[] sig,uint256[] nounceAndtimestamp) external returns(bool){
        //验证地址签名
        if(checkSign(keccak256(nounceAndtimestamp),sig) != platAddr){
            setTrustThresholdEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断             
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],platAddr)){
            setTrustThresholdEvent(msg.sender, false, "重复请求");
            return false;
        }   
        trustThreshold = value;
        setTrustThresholdEvent(msg.sender,true,"信任值设置成功");
        return true;
    }

    /* 添加/修改/删除信任设备 */
    // 参数: 设备地址, 信任值, 操作码(0:添加,1:修改,2:删除), 签名, nounce与时间戳
    function setDevices(address deviceAddr,int trustValue,uint8 opCode,bytes32[] sig,uint256[] nounceAndtimestamp) external returns(bool){
        //验证地址签名
        if(checkSign(keccak256(nounceAndtimestamp),sig) != platAddr){
            setDevicesEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断             
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],platAddr)){
            setDevicesEvent(msg.sender, false, "重复请求");
            return false;
        }   
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
    // 信任规则包装函数  一般调用时使用
    function trustRuleJudgePackage(address platAddr, address deviceAddr) constant public returns(bool, string) {
        bool judgeResult;
        bytes32 judgeMessage;
        (judgeResult,judgeMessage) = trustRuleJudge(platAddr,deviceAddr);
        return (judgeResult, bytes32ToString(judgeMessage));
    }

    UserSceneRule userScene;
    /* 联动步骤开始 (1.调用用户场景规则 2.再嵌套调用联动规则 3.调用受控平台信任规则 4.最后写入联动记录)*/
    // 用户参数输入:[联动平台地址,联动设备地址,受控平台地址,受控设备地址],控制属性,控制状态,用户规则合约
    function startLinking(address[4] addr4, address userSceneRuleAddr, string attrType, string attrState,bytes32[] sig,uint256[] nounceAndtimestamp) 
        external returns(bool){
        //验证地址签名
        if(checkSign(keccak256(addr4[0],addr4[1],addr4[2],addr4[3],userSceneRuleAddr,attrType,attrState,nounceAndtimestamp),sig) != addr4[1]){
            TrustRuleEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断             
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],addr4[1])){
            TrustRuleEvent(msg.sender, false, "重复请求");
            return false;
        }   
        doCall(addr4, userSceneRuleAddr, attrType, attrState, sig, nounceAndtimestamp);
    }
    /* 调用用户场景合约 */
    function doCall(address[4] addr4, address userSceneRuleAddr, string attrType, string attrState,bytes32[] sig,uint256[] nounceAndtimestamp) constant internal returns(bool){
        bool judgeResult;
        string memory judgeMessage;
        (judgeResult,judgeMessage) = trustRuleJudgePackage(addr4[0],addr4[1]);
        if(judgeResult){// 调用信任值判断
            // 继续调用用户场景规则合约
            userScene = UserSceneRule(userSceneRuleAddr);
            bool result = userScene.userSceneRule(addr4, userSceneRuleAddr, attrType, attrState, sig, nounceAndtimestamp);
            if(result){
                TrustRuleEvent(msg.sender, result, "调用成功");
                return true;
            }else{
                return false;
            }
        }else{
            TrustRuleEvent(msg.sender, false, judgeMessage);
            return false;
        }
    }

    /* 转换方法 */
    function bytes32ToString(bytes32 x) constant private returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
    
    /* 签名验证 */
    // 参数:打包后的参数(bytes32), 签名结果([v,r,s])
    function checkSign(bytes32 paramsPackaged, bytes32[] signature) constant private returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(prefix, paramsPackaged);
        return ecrecover(prefixedHash, uint8(signature[0]), signature[1], signature[2]);
    }

    /* 时间和nounce 验证 (用于防止重放攻击)*/
    // 没有使用区块时间(不稳定,可能会被矿工修改),timestamp由用户提供(用户负责)
    // 每一个用户对应一个nounce存储,防止存储越来越大, 
    // 用户提供的时间戳必须要大于存储的时间戳(防止旧请求重放)
    // 参数:用户的随机nounce值,用户提供的时间戳,用户地址 (前两个参数必须经过checkSign验证)
    function checkNounce(uint256 senderNounce, uint256 senderTimeStamp, address senderAddr) private returns(bool){
        Nounce storage list = nounceList[senderAddr];  
        if(list.nounce == senderNounce){ // 匹配到nounce
            return false;
        }else{// 未匹配到
            // 与当前存储的进行比较, 检测timestamp是否过期,
            if(senderTimeStamp <= list.timeStamp){ // (列表为空则默认为0)
                return false;
            }else{
                // 记录下当前的nounce
                list.addr = senderAddr;
                list.timeStamp = senderTimeStamp;
                list.nounce = senderNounce;
                return true;
            }
        }
    }
}