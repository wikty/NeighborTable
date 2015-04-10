1. 针对特定平台进行编译
将如项目目录中，make telosb

2. 将节点插入电脑usb接口中

3. 使用motelist命令查看插入电脑的节点设备
 $ motelist
 windows结果
 Reference  CommPort   Description
 ---------- ---------- ----------------------------------------
 UCC89MXV   COM4       Telos (Rev B 2004-09-27)
 
 linux结果
 Reference  Device           Description
 ---------- ---------------- ---------------------------------------------
 XBS5H6PH   /dev/ttyUSB0     XBOW Crossbow Telos Rev.B

在linux系统上也许你要以supperuser的身份修该连接的usb使其writable
$ chmod 666 /dev/ttyUSB0


4. 安装程序镜像到节点
windows
$ make telosb reinstall bsl,COM4
linux
$ make telosb reinstall bsl,/dev/ttyUSB0
但是如果要在不同的节点上安装镜像就要使用下面的方法：
$ make telosb install.1 bsl,/dev/ttyUSB0
$ make telosb install.2 bsl,/dev/ttyUSB0
$ make telosb install.n bsl,/dev/ttyUSB0
以此类推，每个节点赋予唯一的节点id
上面install和reinstall项的区别在于reinstall会跳过程序的编译步骤而直接将刚刚编译好的程序安装到节点上，而install会重新编译后在进行编译，另外要注意的是其实每个编译的程序都是有id的，系统默认id为1，但是如果你要在多个节点上安装程序的话显然你要通过install来重新编译并指定不同的id了

5. 网络与电脑通信的方案：基站
节点： 安装了特定程序镜像的节点和一个安装了BaseStation的节点

程序镜像节点先连接电脑，通过$ make telosb install,id分别进行安装，要安装BaseStation的节点最后连接到电脑上通过$ make telosb reinstall bsl,/dev/ttyUSB0将BaseStation程序镜像安装到其上

运行电脑上的SerialForwarder程序以获取基站发送来的信息： 
$ java net.tinyos.sf.SerialForwarder -comm serial@/dev/ttyUSB0:telosb

6. 通过PFLAGS或CFLAGS来向nesc编译器传递编译选项，来更改无线通信频率
例： PFLAGS = -DCC1K_DEF_FREQ=100，默认的通信频率是434.845MHz

