pragma solidity ^0.4.11;

/* 注册合约 */
// 用户\平台\设备信息
contract Register {

    struct User {
        string addr;                        // 用户地址
    }

    struct Platform {
        string addr;                            // 平台链上地址
        //int flag;                             // 是否加入联盟章程
        int deviceNum;                          // 注册设备个数
        mapping(string => Device) ownDevices;   // 平台上注册的可联动设备, key: 设备地址
    }

    struct Device {
        string addr;                            // 设备链上地址
        int trustValue;                         // 信任值
        mapping(string => Attribute) deviceAttr;// 设备可控制的属性, key: 属性名
    }

    struct Attribute {
        string attrType;                    // 设备属性类型
        string attrState;                   // 设备属性状态
        //mapping(string => Platform) allowPlatforms;
    }

    int platformNum;                        // 注册平台个数
    mapping(string => Platform) platInfo;   // 注册平台列表
    int userNum;                            // 注册用户个数
    mapping(string => User) usersInfo;      // 注册用户列表

    /* 1 注册平台 */
    // 参数:平台地址,平台名称
    function platformRegister(string platAddr) external returns(bool) {
        if (bytes(platAddr).length == 0) { // 参数检测
            return false;
        }
        if(checkRegister(platAddr, 1, "")){ // 若平台已注册,则退出
            return false;
        }
        platInfo[platAddr].addr = platAddr; //平台链上地址
        platInfo[platAddr].deviceNum = 0;       //初始化设备个数
        platformNum++;
        return true;
    }

    /* 2.1 设备向平台注册 */
    // 参数:平台地址,设备地址,信用值
    function devicesRegister(string platAddr, string deviceAddr, int trustValue) external returns(bool) {
        if ((bytes(platAddr).length == 0) || (bytes(deviceAddr).length == 0) ) { // 参数检测
            return false;
        }
        if(checkRegister(deviceAddr, 2, platAddr)){ // 若设备已注册,则退出
            return false;
        }
        Platform storage platform = platInfo[platAddr];          
        if (bytes(platform.addr).length == 0) {// 若当前无已注册的平台,则退出
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr];     
        // 设置设备各属性
        platform.deviceNum++;
        device.addr = deviceAddr;         
        device.trustValue = trustValue;                     
        return true;
    }
    /* 2.2 设置设备属性 */
    // 参数:平台地址,设备地址,属性名称,属性类型,属性状态
    function devicesSetAttr(string platAddr, string deviceAddr, string deviceAttr,string attrType,string attrState) external returns(bool) {
        if ((bytes(platAddr).length == 0) || (bytes(deviceAddr).length == 0)) { // 参数检测
            return false;
        }
        Platform storage platform = platInfo[platAddr];              
        if (bytes(platform.addr).length == 0) {// 若当前无已注册的平台,则退出
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr]; 
        if (bytes(device.addr).length == 0) {// 若当前无已注册的设备,则退出
            return false;
        }
        // 设置设备属性        
        device.deviceAttr[deviceAttr].attrType = attrType;
        device.deviceAttr[deviceAttr].attrState = attrState;
        return true;
    }

    /* 2.3 设备向平台解注册 */
    // 参数: 平台地址,设备地址
    // TODO: 1.身份认证 2.相关联的属性删除
    function deviceUnRegister(string platAddr, string deviceAddr) external returns(bool) {
        if ((bytes(deviceAddr).length == 0)) { // 参数检测
            return false;
        }
        Platform storage platform = platInfo[platAddr];         
        platform.deviceNum--;
        delete platform.ownDevices[deviceAddr];
        //
        return true;
    }

    /* 3 用户注册 */
    function userRegister(string userAddr) external returns(bool) {
        if (bytes(userAddr).length == 0 ) {
            return false;
        }
        if(checkRegister(userAddr, 0, "")){ //用户已注册
            return false;
        }
        User storage user = usersInfo[userAddr];
        user.addr = userAddr;
        userNum++;
        return true;
    }
    
    /* 检查注册 */
    // 参数:检查地址,检查类型(0:用户,1:平台,2:设备),平台地址(可选,检查设备是否注册时使用)
    function checkRegister(string addr, int opCode, string platAddr) public returns(bool){
        if (bytes(addr).length == 0) {
            return false;
        }
        if(0 == opCode){
            return Tools.equals(usersInfo[addr].addr, addr);
        }else if(1 == opCode){
            return Tools.equals(platInfo[platAddr].ownDevices[addr].addr, addr);
        }else if(2 == opCode){
            return Tools.equals(platInfo[addr].addr, addr);
        }else{
            return false;
        }
    }
}


/* 信任规则合约 —— 与平台一一对应 */
contract TrustRule {
    // 平台信任的设备
    struct Device {
        string addr;                        // 设备链上地址
        int trustValue;                           // 信任值
    }

    address registerConstractAddr;                 // 注册合约地址
    address platformAddr;                          // 定义此规则的平台的地址
    int trustDeviceNum;                           // 平台信任设备个数
    mapping(string => Device) trustDevices;       // 平台信任的的可联动设备映射表, key：设备地址
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
    function setDevices(string deviceAddr,int trustValue,int opCode) external returns(bool){
        if (bytes(deviceAddr).length == 0 ) { // 参数检查
            return false;
        }
        Device storage device = trustDevices[deviceAddr];   
        if(0 == opCode){
            device.addr = deviceAddr;
            device.trustValue = trustValue;
            trustDeviceNum++;
        }else if(1 == opCode){
            device.addr = deviceAddr;
            device.trustValue = trustValue;
        }else if(2 == opCode){
            delete trustDevices[deviceAddr];
        }else{
            return false; // 未知操作符
        }
        return true;
    }

    /* 信任规则函数 */
    // 参数: 平台地址, 设备地址
    function trustRuleJudge(string platAddr, string deviceAddr) public returns(bool) {
        if (bytes(platAddr).length == 0 || bytes(deviceAddr).length == 0) {
            return false;
        }

        // 调用注册合约，查询平台是否注册，设备是否在平台注册
        if(!Register(registerConstractAddr).checkRegister(platAddr,1,"") ||
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
    // 用户参数输入:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性,控制状态,用户规则合约
    function startLinking(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType, string attrState, address userRuleAddr) 
        external{
        if(trustRuleJudge(lPAddr,lDAddr)){// 调用信任值判断
            // 继续调用用户场景规则合约
            userScene = UserSceneRule(userRuleAddr);
            bool result = userScene.userSceneRule(lPAddr, lDAddr, cPAddr, cDAddr, attrType, attrState);
            emit TrustRuleEvent(result,"调用成功");
        }else{
            emit TrustRuleEvent(false,"信任值不够");
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
        string deviceAddr;                                      // 控制设备地址
        string platformAddr;                                    // 控制平台地址
        address trustAddr;                                      // 受控平台信任规则合约地址
        int attrNum;                                            // 可被控制属性总数
        mapping(string => Attribute) controllAttrs;             // 可被控制属性
    }

    struct LinkingDevice {
        string deviceAddr;                                      // 联动设备地址
        string platformAddr;                                    // 联动平台地址
        address ruleAddr;                                        // 联动规则合约地址(由联动平台定义)
        int deviceNum;                                          // 控制的设备个数
        mapping(string => ControlledDevice) controllDevices;    // 用户设置的受控设备, key：受控设备地址
    }


    address usrAddr;                                             // 定义此合约的用户链上地址
    int linkingNums = 0;                                        // 联动规则总数(每一个属性的联动都算数)
    mapping(string => LinkingDevice) userRules;                 // 联动规则表, key: 联动设备地址
    address registerConstractAddr;                               // 注册合约地址

    /* 构造函数 */
    function UserSceneRule(address consAddr) public{
        usrAddr = msg.sender;
        registerConstractAddr = consAddr;
    }

    /* 添加用户场景 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性,联动规则合约地址,受控信任规则合约地址
    function addUserSceneRule(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType, address ruleAddr, address trustAddr) 
        external returns(bool) {
        //参数检查
        LinkingDevice storage linkingDevice = userRules[lDAddr];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[cDAddr];
        Attribute storage attribute = controlledDevice.controllAttrs[attrType];
        linkingDevice.deviceAddr = lPAddr;
        linkingDevice.platformAddr = lDAddr;
        linkingDevice.ruleAddr = ruleAddr;
        linkingDevice.deviceNum++;
        controlledDevice.deviceAddr = cDAddr;
        controlledDevice.platformAddr = cPAddr;
        controlledDevice.trustAddr = trustAddr;
        controlledDevice.attrNum++;
        attribute.deviceType = attrType;
        linkingNums++;
        return true;
    }

    /* 查询用户规则是否正确 */
    // 如果正确则返回联动规则合约地址和信任规则合约地址
    // 参数: 联动表编号
    function checkUserSceneRule(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType) 
        public returns(bool){
        LinkingDevice storage linkingDevice = userRules[lDAddr];
        if (bytes(linkingDevice.deviceAddr).length == 0 || Tools.equals(linkingDevice.deviceAddr, lDAddr)){
            // 联动设备不存在
            return false;
        }
        if (Tools.equals(linkingDevice.platformAddr, lPAddr)){
            // 联动平台不匹配
            return false;
        }
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[cDAddr];
        if (bytes(controlledDevice.deviceAddr).length == 0 || Tools.equals(controlledDevice.deviceAddr, cDAddr)){
            // 受控设备不存在
            return false;
        }
        if (Tools.equals(controlledDevice.platformAddr, cPAddr)){
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
    function userSceneRule(string lPAddr, string lDAddr, string cPAddr, string cDAddr, string attrType, string attrState)
        external returns(bool) {
        // 调用注册合约，查询受控平台和设备是否注册
        if(!checker(lPAddr, lDAddr, cPAddr, cDAddr)){
            return false;
        }
        // 检查用户规则
        if(!checkUserSceneRule(lPAddr, lDAddr, cPAddr, cDAddr, attrType)){
            return false;
        }
        // 调用联动规则合约
        doLinkageRule(lPAddr, lDAddr, cPAddr, cDAddr, attrType,attrState);
        return true;
    }
    
    /* 检测平台和设备注册 */
    function checker(string lPAddr, string lDAddr, string cPAddr, string cDAddr) internal returns(bool){
        if(Register(registerConstractAddr).checkRegister(lPAddr,1,"") 
            && Register(registerConstractAddr).checkRegister(lPAddr,2,lDAddr) 
            && Register(registerConstractAddr).checkRegister(cPAddr,1,"") 
            && Register(registerConstractAddr).checkRegister(cPAddr,2,cDAddr)){
            return true;
        }
        return false;
    }

    /* 获取联动规则和信任规则合约 */
    function getRule(string lDAddr,string cDAddr) internal returns(address, address){
        LinkingDevice storage linkingDevice = userRules[lDAddr];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[cDAddr];
        return (linkingDevice.ruleAddr,controlledDevice.trustAddr);
    }

    function doLinkageRule(string lPAddr, string lDAddr, string cPAddr, string cDAddr, string attrType, string attrState) internal returns(bool){
        // 获取合约地址
        address ruleAddr; // 获取联动规则合约地址
        address trustAddr; // 获取信任规则合约地址
        (ruleAddr,trustAddr) = getRule(lDAddr,cPAddr);
        
        linkage = LinkageRule(ruleAddr);
        bool result = linkage.linkageRule(lPAddr, lDAddr, cPAddr, cDAddr, attrType, attrState, trustAddr);        
    }
}

/* 联动规则合约 */
// 与用户场景合约流程类似， 只是平台需要有自己定义的规则  是否需要细化到属性层面
contract LinkageRule {

    // 联动控制记录
    struct Record{
        string fromPlatAddr;        //联动方平台地址
        string fromDeviceAddr;      //联动设备地址
        string toPlatAddr;          //受控平台地址
        string toDeviceAddr;        //受控设备地址
        string attrType;            //受控设备属性
        string attrState;           //受控设备状态
        int ID;                  //记录ID
    }

    struct Attribute {
        string deviceType;
    }

    struct ControlledDevice {
        string deviceAddr;                                      // 控制设备地址
        string platformAddr;                                    // 控制平台地址
        int attrNum;                                         // 可被控制属性总数
        mapping(string => Attribute) controllAttrs;             // 可被控制属性
    }

    struct LinkingDevice {
        string deviceAddr;                                      // 联动设备地址
        string platformAddr;                                    // 联动平台地址
        int deviceNum;                                          // 控制的设备个数
        mapping(string => ControlledDevice) controllDevices;    // 用户设置的受控设备, key：受控设备地址
    }

    string usrAddr;                                             // 定义此合约的用户链上地址
    int linkingNums = 0;                                        // 联动规则总数(每一个属性的联动都算数)
    mapping(string => LinkingDevice) linkingRules;              // 联动规则表, key: 联动设备地址
    int recordNums = 0;                                         // 联动记录总数
    mapping(int => Record) linkingRecords;                   // 联动记录, key: 交易id

    /* 设置联动规则 */
    // 参数:联动平台地址,联动设备地址,受控平台地址,受控设备地址,控制属性
    function addLinkageRule(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType) 
        external returns(bool) {
        LinkingDevice storage linkingDevice = linkingRules[lDAddr];
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[cDAddr];
        Attribute storage attribute = controlledDevice.controllAttrs[attrType];
        linkingDevice.deviceAddr = lPAddr;
        linkingDevice.platformAddr = lDAddr;
        linkingDevice.deviceNum++;
        controlledDevice.deviceAddr = cDAddr;
        controlledDevice.platformAddr = cPAddr;
        attribute.deviceType = attrType;
        controlledDevice.attrNum++;
        linkingNums++;
        return true;
    }

    /* 查询联动规则是否正确 */
    // 参数: 联动表编号
    function checkLinkageRule(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType) public returns(bool){
        LinkingDevice storage linkingDevice = linkingRules[lDAddr];
        if (bytes(linkingDevice.deviceAddr).length == 0 || Tools.equals(linkingDevice.deviceAddr, lDAddr)){
            // 联动设备不存在
            return false;
        }
        if (Tools.equals(linkingDevice.platformAddr, lPAddr)){
            // 联动平台不匹配
            return false;
        }
        ControlledDevice storage controlledDevice = linkingDevice.controllDevices[cDAddr];
        if (bytes(controlledDevice.deviceAddr).length == 0 || Tools.equals(controlledDevice.deviceAddr, cDAddr)){
            // 受控设备不存在
            return false;
        }
        if ( Tools.equals(controlledDevice.platformAddr, cPAddr)){
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
    function linkageRule(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType, string attrState, address trustAddr)
        external returns(bool) {
        // 查询联动规则是否匹配
        if(!checkLinkageRule(lPAddr, lDAddr, cPAddr, cDAddr, attrType)){
            return false;
        }

        // 调用受控平台信任规则,检查是否能够联动
        trustRule = TrustRule(trustAddr);
        bool result = trustRule.trustRuleJudge(cPAddr,cDAddr);
        if(!result){
            return false;
        }

        // 联动方的联动规则执行,记录联动结果
        recordLink(lPAddr, lDAddr, cPAddr, cDAddr, attrType, attrState);
        return true;
    }

    /* 记录联动控制 */
    function recordLink(string lPAddr, string lDAddr, string cPAddr,string cDAddr, string attrType, string attrState) internal returns(bool){
        Record storage record = linkingRecords[recordNums];
        record.fromPlatAddr = lPAddr;
        record.fromDeviceAddr = lDAddr;
        record.toPlatAddr = cPAddr; 
        record.toDeviceAddr = cDAddr;
        record.attrType = attrType; 
        record.attrState = attrState;
        record.ID = recordNums;
        recordNums++;
        return true;
    }


    /* 查询联动控制记录 */
    function queryRecord(int recordID) external returns(string, string, string,string, string, string, int){
        Record storage record = linkingRecords[recordID];
        return (
            record.fromPlatAddr,
            record.fromDeviceAddr,
            record.toPlatAddr, 
            record.toDeviceAddr,
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