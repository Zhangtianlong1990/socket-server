//
//  ViewController.m
//  socket-server
//
//  Created by 张天龙 on 2022/5/14.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#define VA_COMADN_ID 0x00000001
#define server_port 6969

#define dispatch_main_sync_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_sync(dispatch_get_main_queue(), block);\
}

@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic,strong) GCDAsyncSocket *serverSocket;
@property (nonatomic,strong) NSMutableArray *clientSockets;
@property (nonatomic,strong) NSMutableData *dataM;
@property (nonatomic,assign) unsigned int totalSize;
@property (nonatomic,assign) unsigned int currentCommandId;
@property (nonatomic,weak) UIImageView *imageView;
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
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"断开连接%@",err.localizedDescription);
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
    dispatch_main_sync_safe(^{
        self.imageView.image = acceptImage;
    });
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
