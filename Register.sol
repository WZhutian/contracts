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

    // 在一段时间内不能改变
    struct Nounce {
        address addr;                           //请求者地址
        uint256 nounce;                          //请求者产生的随机值
        uint256 timeStamp;                      //时间戳
    }

    uint platformNum;                        // 注册平台个数
    mapping(address => Platform) platInfo;     // 注册平台列表 key: 平台地址
    uint userNum;                            // 注册用户个数
    mapping(address => User) usersInfo;        // 注册用户列表, key: 用户地址
    mapping(address => Nounce) nounceList;       //nounce列表, key: 用户地址

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
    // 验证: 必须是[设备]进行签名
    // 参数: 平台地址,设备地址,签名结果,[随机数,时间戳]
    function devicesRegister(address platAddr, address deviceAddr,bytes32[] sig,uint256[] nounceAndtimestamp) external returns(bool){
        //验证设备地址签名
        if(checkSign(keccak256(platAddr,deviceAddr,nounceAndtimestamp),sig) != deviceAddr){
            devicesRegisterEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断             
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],deviceAddr)){
            devicesRegisterEvent(msg.sender, false, "重复请求");
            return false;
        }   
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
    // 验证: 必须是[设备]进行签名
    // 参数:平台地址,设备地址,属性名称,属性类型,属性状态
    function devicesSetAttr(address platAddr, address deviceAddr, string attrType,string attrState,bytes32[] sig,uint256[] nounceAndtimestamp) external returns(bool){
        //验证设备地址签名
        if(checkSign(keccak256(platAddr,deviceAddr,attrType,attrState,nounceAndtimestamp),sig) != deviceAddr){
            devicesSetAttrEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断             
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],deviceAddr)){
            devicesSetAttrEvent(msg.sender, false, "重复请求");
            return false;
        }   
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
    // 验证: 必须是[设备]进行签名
    // 参数: 平台地址,设备地址
    // TODO: 相关联的属性删除
    function deviceUnRegister(address platAddr, address deviceAddr,bytes32[] sig,uint256[] nounceAndtimestamp) external returns(bool) {
        //验证设备地址签名
        if(checkSign(keccak256(platAddr,deviceAddr,nounceAndtimestamp),sig) != deviceAddr){
            deviceUnRegisterEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断           
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],deviceAddr)){
            deviceUnRegisterEvent(msg.sender, false, "重复请求");
            return false;
        }   
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

    //新功能测试
    function test(address platAddr, address deviceAddr, string attrType,string attrState,bytes32[] sig,uint256[] nounceAndtimestamp) public returns(bool){
        //验证设备地址签名
        if(checkSign(keccak256(platAddr,deviceAddr,attrType,attrState,nounceAndtimestamp),sig) != deviceAddr){
            deviceUnRegisterEvent(msg.sender, false, "未通过签名认证");
            return false;
        }
        //时间和nounce判断           
        if(!checkNounce(nounceAndtimestamp[0],nounceAndtimestamp[1],deviceAddr)){
            deviceUnRegisterEvent(msg.sender, false, "重复请求");
            return false;
        }   
        deviceUnRegisterEvent(msg.sender, true, "通过");
        
    }

    /* 签名验证 */
    // 参数:打包后的参数(bytes32), 签名结果([v,r,s])
    function checkSign(bytes32 paramsPackaged, bytes32[] signature) constant private returns(address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(prefix, paramsPackaged);
        return ecrecover(prefixedHash, uint8(signature[0]), signature[1], signature[2]);
    }

    /* 时间和nounce 验证 (用于防止重放攻击)*/
    // 没有使用区块时间(不稳定,可能会被矿工修改),timestamp由用户提供
    // 每一个用户对应一个nounce存储,防止存储越来越大, 
    // 用户提供的时间戳必须要大于存储的时间戳(防止旧请求重放)
    // 要求用户发送的时间戳要能够同步 (用户负责)
    // 参数:用户的随机nounce值,用户提供的时间戳,用户地址 (前两个参数必须经过checkSign验证)
    function checkNounce(uint256 senderNounce, uint256 senderTimeStamp, address senderAddr) private returns(bool){
        Nounce storage nounce = nounceList[senderAddr];
        if(nounce.nounce == senderNounce){ // 匹配到nounce
            return false;
        }else{// 未匹配到
            // 与当前存储的进行比较, 检测timestamp是否过期,
            if(senderTimeStamp<nounce.timeStamp){
                return false;
            }else{
                // 记录下当前的nounce
                nounce.addr = senderAddr;
                nounce.timeStamp = senderTimeStamp;
                nounce.nounce = senderNounce;
                return true;
            }
        }
    }
}