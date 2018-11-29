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
    function checkRegister(address addr, uint8 opCode, address platAddr) public returns(bool){

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