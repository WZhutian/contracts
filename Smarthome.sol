pragma solidity ^0.4.2;
import "LibString.sol";
import "LibLog.sol";


//SmartHome Contract
contract Smarthome {
    /* State Virable -- contract data modle */
    // Relate Info
    struct Relate {
        string addr;        //地址
        string pubkey;      //公钥
        int64 timestamp;    //关联建立时间
        int index;          //关联索引，从0开始. 用户关联设备只有一个，index为0；设备用户是列表，index为关联时的计数.        
    }

    // Device: key is device addr
    struct Device {
        string addr;        //设备地址
        string pubkey;      //设备公钥
        int64 timestamp;    //注册时间
        Relate user;        //关联用户
    }

    //User: key is user addr
    struct User {
        string addr;        //用户地址
        string pubkey;      //用户公钥
        int64 timestamp;    //注册时间
        int relateDevNum;   //关联设备个数
        mapping(string => Relate) relateDevs;    //所有关联设备，key是设备地址
        mapping(int => string) relateDevsEntry;  //关联设备的地址列表，key是关联计数
    }

    //all User's Information Map
    int64 userNum;
    mapping(string => User) usersInfo;
    //all Device's Information Map
    int64 deviceNum;
    mapping(string => Device) devsInfo;
    //contract owner -- init in constructor
    address owner;
    //Prevent the calling times of the interface in the loop from exceeding the limit, consuming extra gas.
    bool reEntrancyMutex = false;

    //Notify Code
    enum OptError {
        NO_ERROR,
        PARAM_EMPTY,
        HAS_REGISTERED,
        ITEM_NOT_EXISTS,
        HAS_RELATED,
        EXCEED_INDEX
    }

    /* Event Definition -- log data on the blockChain */
    //实际作用只是存证？ 真正查询只在合约数据结构层查询？
    event RecoredUserRegisterEvent(string addr, string pubkey, int64 timestamp);
    event RecoredDeviceRegisterEvent(string addr, string pubkey, int64 timestamp);
    event BindDeviceAndUserEvent(string usraddr, string usrpubkey, int relateNum, string devAddr, string devPubkey, int64 timestamp);
    event UnbindDeviceAndUserEvent(string usraddr, string usrpubkey, int relateNum, string devAddr, string devPubkey, int64 timestamp);
    event QueryDeviceEvent(string devAddr, string devPubkey, int64 devTmp, string usraddr, string usrpubkey, int64 relateTmp);
    event QueryUserEvent(string usraddr, string usrpubkey, int64 usrTmp, string devAddr, string devPubkey, int64 relateTmp);
    event GetRelatedDevNumEvent(string usraddr, int relateDevNum);
    //event Notify(uint _errno, string _info);

    // if the calller is not the contract owner, throw an excepion
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }
    
    /* 
     * Contract Function 
     * Notice: External Function parmas can not be struct, neither does Function return value.
     */
    //construtor
    function Smarthome() {
        owner = msg.sender;
    }

    // Device Register Function
    function deviceRegister(string devAddr, string devPubKey, int64 devTms, string devScript) external returns(bool) {
        //设备地址合法性检查、公钥合法性检查、验证时间戳、验证签名
        if (bytes(devScript).length == 0) {
            return false;
        }
        //检查设备是否已经注册
        
        bool ifDevReg = checkDeviceRegistry(devAddr);
        if (true == ifDevReg) {
            LibLog.log("device has already rigistered, addr:", devAddr);
            //Notify(uint(OptError.HAS_REGISTERED), "Device has already registered!");
            return false;
        }

        //存储注册设备的信息
        //devsInfo[devAddr] = Device(devAddr, devPubKey, devTms);
        devsInfo[devAddr].addr = devAddr;
        devsInfo[devAddr].pubkey = devPubKey;
        devsInfo[devAddr].timestamp = devTms;
        //struct cannot be assigned so while constructing maps we ignore the struct member

        //记录设备注册事件到链上
        deviceNum++;
        RecoredDeviceRegisterEvent(devAddr, devPubKey, devTms);   //new emit keyword    
        //Notify(uint(OptError.NO_ERROR), "Device register success!");

        return true;
    }

    // User Register Function
    function userRegister(string usrAddr, string usrPubKey, int64 usrTms, string usrScript) external returns(bool) {
        //用户地址合法性检查、公钥合法性检查、验证时间戳、验证签名
        if (bytes(usrScript).length == 0) {
            return false;
        }
        //检查用户是否已经注册
        bool ifUsrReg = checkUserRegistry(usrAddr);
        if (true == ifUsrReg) {
            LibLog.log("User has already rigistered, addr:", usrAddr);
            //Notify(uint(OptError.HAS_REGISTERED), "User has already registered!");
            return false;
        }

        //存储注册用户的信息
        usersInfo[usrAddr] = User(usrAddr, usrPubKey, usrTms, 0);
        //maps cannot be assigned so while constructing struct we ignore the maps member

        //记录用户注册事件到链上
        userNum++;
        RecoredUserRegisterEvent(usrAddr, usrPubKey, usrTms);
        //Notify(uint(OptError.NO_ERROR), "User register success!");

        return true;
    }

    /*
    function testDeviceRigister(string devAddr) external returns(bool) {
        if (bytes(devAddr).length == 0) {
            return false;
        }
        Device storage dev = devsInfo[devAddr];
        if (bytes(dev.addr).length == 0) {
            return false;
        }

        bool isSame = LibString.equals(dev.addr, devAddr);
        return isSame;
    }

    // Test interface: check wheather the User has rigistered
    function testUsriceRigister(string usrAddr) external returns(bool) {
        if (bytes(usrAddr).length == 0) {
            return false;
        }
        User storage usr = usersInfo[usrAddr];
        if (bytes(usr.addr).length == 0) {
            return false;
        }

        bool isSame = LibString.equals(usr.addr, usrAddr);
        return isSame;
    }
    */

    // Query the Device's Relationship
    function queryDevice(string devAddress) external returns(string, string, int64, string, string, int64) {
        if (bytes(devAddress).length == 0) {
            //Notify(uint(OptError.PARAM_EMPTY), "Query User param is invaild!");
            LibLog.log("Query User param is invaild, addr:", devAddress);
            return("", "", 0, "", "", 0);
        }
        // query the user bound to the device, if there's anuser 
        Device memory dev = devsInfo[devAddress];
        string memory devAddr = dev.addr;
        string memory devPubkey = dev.pubkey;
        Relate memory relateUsr = dev.user;

        QueryDeviceEvent(devAddr, devPubkey, dev.timestamp, relateUsr.addr, relateUsr.pubkey, relateUsr.timestamp);
        return(devAddr, devPubkey, dev.timestamp, relateUsr.addr, relateUsr.pubkey, relateUsr.timestamp);
    }

    // Query the User's Relationship: Get the related devices' information one by one
    function queryUser(int index, string usrAddr) external returns(string, string, int64) {
        if (bytes(usrAddr).length == 0) {
            //Notify(uint(OptError.PARAM_EMPTY), "Query Device param is invaild!");
            LibLog.log("Query Device param is invaild!");
            return ("", "", 0);
        }

        //prevent reentrancy
        //require(false == reEntrancyMutex);
        User storage user = usersInfo[usrAddr];
        if (bytes(user.addr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "User for quering is not rigistered!");
            LibLog.log("User for quering is not rigistered!");
            QueryUserEvent(" ", " ", 0, " ", " ", 0);
            return ("", "", 0);
        }

        /*
        int maxIndex = user.relateDevNum - 1;
        if (index < maxIndex) {
            LibLog.log("Query user related device index : ", user.relateDevNum);
            require(false == reEntrancyMutex);
        }else if (index == maxIndex) {
            LibLog.log("Query user index reaches the relate numbers: ", user.relateDevNum);
            reEntrancyMutex = true;    // index starts from 0
        }else {
            //Notify(uint(OptError.EXCEED_INDEX), "Query user index exceed the relate numbers!");
            LibLog.log("Query user index exceed the relate numbers: ", user.relateDevNum);
            return ("", "", 0);
        }
        */

        string storage devAddr = usersInfo[usrAddr].relateDevsEntry[index];
        if (bytes(devAddr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "The device is not exist!");
            //LibLog.log("The device is not exist!");
            QueryUserEvent(user.addr, user.pubkey, user.timestamp, " ", " ", 0);
            return(" ", " ", 0);
        }else {
            string storage devAddress = user.relateDevs[devAddr].addr;
            if (bytes(devAddress).length == 0){
                QueryUserEvent(user.addr, user.pubkey, user.timestamp, " ", " ", 0);
                return("", "", 0);
            }else {
                string storage devPubkey = user.relateDevs[devAddr].pubkey;
                int64 devTmp = user.relateDevs[devAddr].timestamp;
                QueryUserEvent(user.addr, user.pubkey, user.timestamp, devAddress, devPubkey, devTmp);
                return(devAddress, devPubkey, devTmp);
            }
        }
    }

    // Get the totoal number of devices bound to the user
    function getDevicesNumberByUsr(string usrAddr) external returns(int) {
        if (bytes(usrAddr).length == 0) {
            return 0;
        }
        if (bytes(usersInfo[usrAddr].addr).length == 0) {
            return 0;
        }
        GetRelatedDevNumEvent(usrAddr, usersInfo[usrAddr].relateDevNum);
        return usersInfo[usrAddr].relateDevNum;
    }

    /* Reset the RelationShip of User and Device
     * Input:
     *    opcode:  1:绑定  2:解绑
     */
    function resetrelate(string usrAddr, string devAddr, int64 timestamp, int opcode, string script) external returns(bool) {
        //检查入参合法性/验证签名 -- 单独接口
        if ((bytes(usrAddr).length == 0) || (bytes(devAddr).length == 0)) {
            return false;
        }
        if (bytes(script).length == 0) {
            return false;
        }
        bool ret = false;

        //Bind or Unbind
        if (1 == opcode) {
            ret = bindDeviceToUser(usrAddr, devAddr, timestamp);
        }else if (2 == opcode) {
            ret = unbindDeviceToUser(usrAddr, devAddr, timestamp);
        }else {
            //maybe log should happen
        }

        return ret;
    }

    // Bind User and Device -- caller should make sure input is vaild
    function bindDeviceToUser(string usrAddr, string devAddr, int64 timestamp) private returns(bool) {
        //检查入参合法性/验证签名 -- 单独接口
        if ((timestamp < user.timestamp) || (timestamp < dev.timestamp)) {
            //return false;      //  wrong binding time before user or device registering
        }
        
        //Recheck and find the Device
        Device storage dev = devsInfo[devAddr];
        if (bytes(dev.addr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "Device for binding is not exist!");
            LibLog.log("Device for binding is not exist!");
            return false;
        }

        //Recheck and find the User
        User storage user = usersInfo[usrAddr];
        if (bytes(user.addr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "User for binding is not exist!");
            LibLog.log("User for binding is not exist!");
            return false;
        }

        //check bindness
        if (bytes(dev.user.addr).length != 0) {
            //user [%s dev.user.addr] has bound to the device [%s devAddr], user should unbind first.
            //Notify(uint(OptError.HAS_RELATED), "Device has alreday bind to a user, user should unbind first");
            LibLog.log("Device has alreday bind to a user, user should unbind first");
            return false;
        }

        //Recored Device Info at User
        //device relate index starts from 0
        user.relateDevs[devAddr] = Relate(dev.addr, dev.pubkey, timestamp, user.relateDevNum);
        user.relateDevsEntry[user.relateDevNum] = dev.addr;
        user.relateDevNum++;

        //Recored User Info to Device
        dev.user = Relate(user.addr, user.pubkey, timestamp, 0);   //user Relate Index should always be 0
        BindDeviceAndUserEvent(user.addr, user.pubkey, user.relateDevNum, dev.addr, dev.pubkey, timestamp);

        return true;
    }

    // Unbind User and Device
    function unbindDeviceToUser(string usrAddr, string devAddr, int64 timestamp) private returns(bool) {
        //检查入参合法性/验证签名 -- 单独接口
        //if (timestamp < user.timestamp) {
            //return false;      //  wrong binding time before user or device registering
        //}

        //Recheck and find the Device
        Device storage dev = devsInfo[devAddr];
        if (bytes(dev.addr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "User for unbinding is not exist!");
            LibLog.log("Device for unbinding is not exist!");
            return false;
        }

        //Recheck and find the User
        User storage user = usersInfo[usrAddr];
        if (bytes(user.addr).length == 0) {
            //Notify(uint(OptError.ITEM_NOT_EXISTS), "Device for unbinding is not exist!");
            LibLog.log("User for unbinding is not exist!");
            return false;
        }

        //Clear Recored Device Info at User 
        user.relateDevNum--;
        //string memory pubkey1 = user.pubkey;
        //int reNum = user.relateDevNum;
        //string memory pubkey2 = dev.pubkey;
        //UnbindDeviceAndUserEvent(usrAddr, pubkey1, reNum, devAddr, pubkey2, timestamp);
        UnbindDeviceAndUserEvent(user.addr, user.pubkey, user.relateDevNum, dev.addr, dev.pubkey, timestamp);

        int index = user.relateDevs[devAddr].index;
        user.relateDevs[devAddr] = Relate("", "", 0, 0);
        user.relateDevsEntry[index] = "";
        //delete user.relateDevs[devAddr];
        //delete user.relateDevsEntry[index];

        //Clear Recored Device Info at Device
        dev.user = Relate("", "", 0, 0);
        //can't delete dev.usr

        return true;
    }

    /* Check Device's Registry Function
     * Innput:   
     *     devAddr:  device’s address
     * Output:
     *     none
     * Return:
     *     false -- not rigistered
     *     true  -- already rigistered
     * Caution:
     *     error occurs throw a Excepions
     *     calller should make sure input is not null string
     */
    function checkDeviceRegistry(string devAddr) private returns(bool) {

        Device storage dev = devsInfo[devAddr];
        // No checking device
        if (bytes(dev.addr).length == 0) {
            return false;
        }
        // Not the right device we are checking
        bool isSame = LibString.equals(dev.addr, devAddr);
        if (true == isSame) {
            return true;
        }else {
            //Notify(uint(OptError.HAS_REGISTERED), "Different Device has alreday registered!");
            LibLog.log("Different Device has alreday registered!");
            revert();  //异常  should be?
        }
    }

    /* Check User's Registry Function
     * Innput:   
     *     usrAddr:  user’s address
     * Output:
     *     none
     * Return:
     *     false -- not rigistered
     *     true  -- already rigistered
     * Caution:
     *     error occurs throw a Excepions
     *     calller should make sure input is not null string
     */
    function checkUserRegistry(string usrAddr) private returns(bool) {

        User storage usr = usersInfo[usrAddr];
        // No checking device
        if (bytes(usr.addr).length == 0) {
            return false;
        }
        // Not the right device we are checking
        bool isSame = LibString.equals(usr.addr, usrAddr);
        if (true == isSame) {
            return true;
        }else {
            //Notify(uint(OptError.HAS_REGISTERED), "Different User has alreday registered!");
            LibLog.log("Different User has alreday registered!");
            revert();  //异常
        }
    }

    // Get the related devices' entry each by its index， caller should make sure usrAddr is not null.
    function getRelatedDevEntry(int index, string usrAddr) private returns(string) {
        //should index starts from 0 ?
        string memory devAddr = usersInfo[usrAddr].relateDevsEntry[index];
        return devAddr;
    }

}
