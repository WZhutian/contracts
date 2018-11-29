pragma solidity ^0.4.11;

/* 注册合约 */
// 用户\平台\设备信息
contract Register {

    struct User {
        address addr;                        // 用户地址
    }

    struct Platform {
        address addr;                            // 平台链上地址
        //int flag;                             // 是否加入联盟章程
        uint deviceNum;                          // 注册设备个数
        mapping(address => Device) ownDevices;   // 平台上注册的可联动设备, key: 设备地址
    }

    struct Device {
        address addr;                            // 设备链上地址
        // int trustValue;                       // 信任值 (没有作用)
        mapping(string => Attribute) deviceAttr;// 设备可控制的属性, key: 属性名
    }

    struct Attribute {
        string attrType;                    // 设备属性类型
        string attrState;                   // 设备属性状态
        //mapping(address => Platform) allowPlatforms;
    }

    uint platformNum;                        // 注册平台个数
    mapping(address => Platform) platInfo;     // 注册平台列表 key: 平台地址
    uint userNum;                            // 注册用户个数
    mapping(address => User) usersInfo;        // 注册用户列表, key: 用户地址

    /* 1 注册平台 */
    // 参数:平台地址,平台名称
    function platformRegister(address platAddr) external returns(bool) {
        if(checkRegister(platAddr, 1, address(0))){ // 若平台已注册,则退出
            return false;
        }
        platInfo[platAddr].addr = platAddr; //平台链上地址
        platInfo[platAddr].deviceNum = 0;       //初始化设备个数
        platformNum++;
        return true;
    }

    /* 2.1 设备向平台注册 */
    // 参数:平台地址,设备地址
    function devicesRegister(address platAddr, address deviceAddr) external returns(bool) {
        if(checkRegister(deviceAddr, 2, platAddr)){ // 若设备已注册,则退出
            return false;
        }
        Platform storage platform = platInfo[platAddr];          
        if (platform.addr == address(0)) {// 若当前无已注册的平台,则退出
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr];     
        // 设置设备各属性
        platform.deviceNum++;
        device.addr = deviceAddr;                           
        return true;
    }
    /* 2.2 设置设备属性 */
    // 参数:平台地址,设备地址,属性名称,属性类型,属性状态
    function devicesSetAttr(address platAddr, address deviceAddr, string attrType,string attrState) external returns(bool) {

        Platform storage platform = platInfo[platAddr];              
        if (platform.addr == address(0)) {// 若当前无已注册的平台,则退出
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr]; 
        if (device.addr == address(0)) {// 若当前无已注册的设备,则退出
            return false;
        }
        // 设置设备属性        
        device.deviceAttr[attrType].attrType = attrType;
        device.deviceAttr[attrType].attrState = attrState;
        return true;
    }

    /* 2.3 设备向平台解注册 */
    // 参数: 平台地址,设备地址
    // TODO: 1.身份认证 2.相关联的属性删除
    function deviceUnRegister(address platAddr, address deviceAddr) external returns(bool) {

        Platform storage platform = platInfo[platAddr];         
        platform.deviceNum--;
        delete platform.ownDevices[deviceAddr];
        //
        return true;
    }

    /* 3 用户注册 */
    function userRegister(address userAddr) external returns(bool) {

        if(checkRegister(userAddr, 0, address(0))){ //用户已注册
            return false;
        }
        User storage user = usersInfo[userAddr];
        user.addr = userAddr;
        userNum++;
        return true;
    }
    
    /* 检查注册 */
    // 参数:检查地址,检查类型(0:用户,1:平台,2:设备),平台地址(可选,检查设备是否注册时使用)
    function checkRegister(address addr, int8 opCode, address platAddr) public returns(bool){

        if(uint8(0) == opCode){
            return usersInfo[addr].addr == addr;
        }else if(uint8(1) == opCode){
            return platInfo[platAddr].ownDevices[addr].addr == addr;
        }else if(uint8(2) == opCode){
            return platInfo[addr].addr == addr;
        }else{
            return false;
        }
    }
}


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

    /* 合约执行结果的事件通知 */
    event TrustRuleEvent(bool result,string message);

    /* 构造函数 */
    function TrustRule(address consAddr) public{
        platformAddr = msg.sender;
        registerConstractAddr = consAddr;
    }
    
    /* 设置信任阈值 */
    // 参数: 信任值
    function setTrustThreshold(int value) external returns(bool){
        trustThreshold = value;
        return true;
    }

    /* 添加/修改/删除信任设备 */
    // 参数: 设备地址, 信任值, 操作码(0:添加,1:修改,2:删除)
    function setDevices(address deviceAddr,int trustValue,int8 opCode) external returns(bool){

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
            return false; // 未知操作符
        }
        return true;
    }

    /* 信任规则函数 */
    // 参数: 平台地址, 设备地址
    function trustRuleJudge(address platAddr, address deviceAddr) public returns(bool) {

        // 调用注册合约，查询平台是否注册，设备是否在平台注册
        if(!Register(registerConstractAddr).checkRegister(platAddr,1,address(0)) ||
            !Register(registerConstractAddr).checkRegister(platAddr,2,deviceAddr)){
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
            TrustRuleEvent(result,"调用成功");
        }else{
            TrustRuleEvent(false,"信任值不够");
        }
    }
}

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
    function checkUserSceneRule(address[4] addr4, string attrType) 
        public returns(bool){
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

    address usrAddr;                                             // 定义此合约的用户链上地址
    uint linkingNums = 0;                                        // 联动规则总数(每一个属性的联动都算数)
    mapping(address => LinkingDevice) linkingRules;              // 联动规则表, key: 联动设备地址
    uint recordNums = 0;                                         // 联动记录总数
    mapping(uint => Record) linkingRecords;                   // 联动记录, key: 交易id

    /* 设置联动规则 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性
    function addLinkageRule(address[4] addr4, string attrType) 
        external returns(bool) {
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
        return true;
    }

    /* 查询联动规则是否正确 */
    // 参数: 
    function checkLinkageRule(address[4] addr4, string attrType) public returns(bool){
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
        if (bytes(attribute.deviceType).length == 0  || Tools.equals(attribute.deviceType, attrType)){
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
        // 查询联动规则是否匹配
        if(!checkLinkageRule(addr4, attrType)){
            return false;
        }

        // 调用受控平台信任规则,检查是否能够联动
        trustRule = TrustRule(trustAddr);
        bool result = trustRule.trustRuleJudge(addr4[2],addr4[3]);
        if(!result){
            return false;
        }

        // 联动方的联动规则执行,记录联动结果
        recordLink(addr4, attrType, attrState);
        return true;
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
    function queryRecord(uint recordID) external returns(address, address, address, address, string, string, uint){
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