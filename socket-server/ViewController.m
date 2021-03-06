//
//  ViewController.m
//  socket-server
//
//  Created by 张天龙 on 2022/5/14.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#define VA_COMADN_ID 0x00000001
#define VA_COMADN_HEARTBEAT_ID 0x00000002
#define server_port 6969

#define dispatch_main_async_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }

@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong) GCDAsyncSocket *serverSocket;
@property (nonatomic,strong) NSMutableArray *clientSockets;
@property (nonatomic,strong) NSMutableData *dataM;
@property (nonatomic,assign) unsigned int totalSize;
@property (nonatomic,assign) unsigned int currentCommandId;
@property (nonatomic,weak) UIImageView *imageView;
@property (nonatomic,strong) NSTimer *heartBeatRemainTimer;
@end

@implementation ViewController

- (NSMutableArray *)clientSockets{
    if (_clientSockets==nil) {
        _clientSockets = [NSMutableArray array];
    }
    return _clientSockets;
}

- (NSMutableData *)dataM{
    if (_dataM == nil) {
        _dataM = [NSMutableData data];
    }
    return _dataM;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initUI];
    [self initGCDAsyncSocket];
}

- (void)initGCDAsyncSocket{
    //创建socket
    if (_serverSocket == nil) {
        _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(0, 0)];
    }
}

//初始化心跳
- (void)initHeartBeat
{
 
    dispatch_main_async_safe(^{
 
        [self destoryHeartBeat];
 
        __weak typeof(self) weakSelf = self;
        //心跳设置为3分钟，NAT超时一般为5分钟
        //客户端超过5分钟没有发送心跳包就disconnect了
        self.heartBeatRemainTimer = [NSTimer scheduledTimerWithTimeInterval:5*60 repeats:NO block:^(NSTimer * _Nonnull timer) {
            NSLog(@"heart Beat time out");
            //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
            [weakSelf disConnect];
        }];
        [[NSRunLoop currentRunLoop]addTimer:self.heartBeatRemainTimer forMode:NSRunLoopCommonModes];
    })
 
}

//取消心跳
- (void)destoryHeartBeat
{
    dispatch_main_async_safe(^{
        if (self.heartBeatRemainTimer) {
            [self.heartBeatRemainTimer invalidate];
            self.heartBeatRemainTimer = nil;
            NSLog(@"heartBeat Timer destory");
        }
    })
 
}

- (BOOL)accept{
    NSError *error = nil;
    BOOL success = [_serverSocket acceptOnPort:server_port error:&error];
    if (success) {
        NSLog(@"服务开启成功");
    }else{
        NSLog(@"服务开启失败");
    }
    return success;
}

- (void)disConnect{
    for (GCDAsyncSocket *sock in self.clientSockets) {
        [sock disconnect];
    }
    [self.clientSockets removeAllObjects];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    NSLog(@"当前客户端的IP:%@,端口号:%d",newSocket.connectedHost,newSocket.connectedPort);
    [self.clientSockets addObject:newSocket];
    NSLog(@"当前有%ld个客户端连接",self.clientSockets.count);
    [self initHeartBeat];
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"断开连接,errorCode = %ld,err.localizedDescription = %@",err.code,err.localizedDescription);
    //断开连接时销毁心跳
    [self destoryHeartBeat];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    //第一次接收数据
    if (self.dataM.length==0) {
        //获取总的数据包大小
        NSData *totalSizeData = [data subdataWithRange:NSMakeRange(0, 4)];
        unsigned int totalSize = 0;
        [totalSizeData getBytes:&totalSize length:4];
        NSLog(@"接收的总数据大小为%u",totalSize);
        self.totalSize = totalSize;
        
        //获取命令类型
        NSData *commandIdData = [data subdataWithRange:NSMakeRange(4, 4)];
        unsigned int commandId = 0;
        [commandIdData getBytes:&commandId length:4];
        self.currentCommandId = commandId;
        
        switch (commandId) {
            case VA_COMADN_ID:
                NSLog(@"此次数据是图片类型");
                break;
            case VA_COMADN_HEARTBEAT_ID:
                NSLog(@"此次数据是心跳包");
                break;
            default:
                NSLog(@"未知");
                break;
        }
        
    }
    
  //拼接二进制
    [self.dataM appendData:data];
    
    NSLog(@"此次接收的数据包大小%ld",data.length);
    
    if (self.dataM.length == self.totalSize) {
        NSLog(@"数据已经接收完成");
        if (self.currentCommandId == VA_COMADN_ID) {
            [self saveImage];
        }else if (self.currentCommandId == VA_COMADN_HEARTBEAT_ID){
            [self handleHeartBeat];
        }
        //响应客户端
    }
    
    [sock readDataWithTimeout:-1 tag:0];
    
}

- (void)didClickAcceptButton{
    [self accept];
}

- (void)didClickDisconnectButton{
    [self disConnect];
}

#pragma mark - private

- (CGFloat)screenWidth{
    return [UIScreen mainScreen].bounds.size.width;
}

- (UIButton *)creatButtonWithTitle:(NSString *)title action:(SEL)action{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor blueColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)saveImage{
    NSData *imageData = [self.dataM subdataWithRange:NSMakeRange(8, self.dataM.length-8)];
    UIImage *acceptImage = [UIImage imageWithData:imageData];
    dispatch_main_async_safe(^{
        self.imageView.image = acceptImage;
    });
    self.dataM = nil;
}

- (void)handleHeartBeat{
    //接收到心跳包，重置定时器
    [self initHeartBeat];
    self.dataM = nil;
}

#pragma mark - UI

- (void)initUI{
    CGFloat buttonWidth = 100;
    CGFloat buttonHeight = 50;
    CGFloat acceptY = 100;
    CGFloat acceptX = ([self screenWidth] - buttonWidth)*0.5;
    CGRect acceptF = CGRectMake(acceptX, acceptY, buttonWidth, buttonHeight);
    UIButton *acceptButton = [self creatButtonWithTitle:@"开启服务" action:@selector(didClickAcceptButton)];
    acceptButton.frame = acceptF;
    [self.view addSubview:acceptButton];

    CGFloat imageY = CGRectGetMaxY(acceptF) + 50;
    CGRect imageF = CGRectMake(acceptX, imageY, buttonWidth, buttonWidth);
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.frame = imageF;
    imageView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:imageView];
    self.imageView = imageView;
    
    CGFloat disconnectY = CGRectGetMaxY(imageF) + 50;
    CGFloat disconnectX = acceptX;
    CGRect disconnectF = CGRectMake(disconnectX, disconnectY, buttonWidth, buttonHeight);
    UIButton *disconnectButton = [self creatButtonWithTitle:@"断开" action:@selector(didClickDisconnectButton)];
    disconnectButton.frame = disconnectF;
    [self.view addSubview:disconnectButton];
    
}


@end
