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

    /* 事件响应 */
    event platformRegisterEvent(address sender, bool result, string message);
    event devicesRegisterEvent(address sender, bool result, string message);
    event devicesSetAttrEvent(address sender, bool result, string message);
    event deviceUnRegisterEvent(address sender, bool result, string message);
    event userRegisterEvent(address sender, bool result, string message);

    /* 1 注册平台 */
    // 参数:平台地址,平台名称
    function platformRegister(address platAddr) external returns(bool){
        if(checkPlatformRegister(platAddr)){ // 若平台已注册,则退出
            platformRegisterEvent(msg.sender, false, "平台已注册");
            return false;
        }
        platInfo[platAddr].addr = platAddr; //平台链上地址
        platInfo[platAddr].deviceNum = 0;  //初始化设备个数
        platformNum++;
        platformRegisterEvent(msg.sender, true, "注册成功");
        return true;
    }

    /* 2.1 设备向平台注册 */
    // 参数:平台地址,设备地址
    function devicesRegister(address platAddr, address deviceAddr) external returns(bool){
        if(checkDeviceRegister(platAddr, deviceAddr)){ // 若设备已注册,则退出
            devicesRegisterEvent(msg.sender, false, "设备已注册");
            return false;
        }
        Platform storage platform = platInfo[platAddr];          
        if (platform.addr == address(0)) {// 若当前无已注册的平台,则退出
            devicesRegisterEvent(msg.sender, false, "当前无已注册的平台");
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr];     
        // 设置设备各属性
        platform.deviceNum++;
        device.addr = deviceAddr;  
        devicesRegisterEvent(msg.sender, true, "设备注册成功");
        return true;
    }
    /* 2.2 设置设备属性 */
    // 参数:平台地址,设备地址,属性名称,属性类型,属性状态
    function devicesSetAttr(address platAddr, address deviceAddr, string attrType,string attrState) external returns(bool){
        Platform storage platform = platInfo[platAddr];              
        if (platform.addr == address(0)) {// 若当前无已注册的平台,则退出
            devicesSetAttrEvent(msg.sender, false, "无已注册的平台");
            return false;
        }
        Device storage device = platform.ownDevices[deviceAddr]; 
        if (device.addr == address(0)) {// 若当前无已注册的设备,则退出
            devicesSetAttrEvent(msg.sender, false, "无已注册的设备");
            return false;
        }
        // 设置设备属性        
        device.deviceAttr[attrType].attrType = attrType;
        device.deviceAttr[attrType].attrState = attrState;
        devicesSetAttrEvent(msg.sender, true, "设备属性设置成功");
        return true;
    }

    /* 2.3 设备向平台解注册 */
    // 参数: 平台地址,设备地址
    // TODO: 1.身份认证 2.相关联的属性删除
    function deviceUnRegister(address platAddr, address deviceAddr) external returns(bool) {

        Platform storage platform = platInfo[platAddr];         
        platform.deviceNum--;
        delete platform.ownDevices[deviceAddr];
        deviceUnRegisterEvent(msg.sender, true, "设备解注册成功");
    }

    /* 3 用户注册 */
    function userRegister(address userAddr) external returns(bool) {
        if(checkUserRegister(userAddr)){ //用户已注册
            userRegisterEvent(msg.sender, false, "用户已注册");
            return false;
        }
        User storage user = usersInfo[userAddr];
        user.addr = userAddr;
        userNum++;
        userRegisterEvent(msg.sender, true, "用户注册成功");
        return true;
    }
    
    /* 检查注册 */
    // 参数:检查地址,平台地址(可选,检查设备是否注册时使用)
    function checkUserRegister(address addr) constant public returns(bool){
        return usersInfo[addr].addr == addr;
    }
    function checkDeviceRegister(address platAddr,address addr) constant public returns(bool){
        return platInfo[platAddr].ownDevices[addr].addr == addr;
    }
    function checkPlatformRegister(address addr) constant public returns(bool){
        return platInfo[addr].addr == addr;
    }

    //测试签名
    function test(address a,address b,string c,string d,bytes32[] sig,address addr) constant public returns(bool){
        bytes32 params = keccak256(a,b,c,d);
        return checkSign(params,sig) == addr;
    }

    /* 签名验证 */
    // 参数:打包后的参数(string), 签名结果([v,r,s]), 参考地址
    function checkSign(bytes32 paramsPackaged, bytes32[] signature) constant private returns(address) {
        return ecrecover(paramsPackaged, uint8(signature[0]), signature[1], signature[2]);
    }

}