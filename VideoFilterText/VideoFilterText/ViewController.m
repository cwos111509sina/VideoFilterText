//
//  ViewController.m
//  VideoFilterText
//
//

#import "ViewController.h"

#import "GPUImage.h"

#import <AssetsLibrary/AssetsLibrary.h>

#define WIDTH [UIScreen mainScreen].bounds.size.width
#define HEIGHT [UIScreen mainScreen].bounds.size.height


#define WINDOW [[UIApplication sharedApplication] keyWindow]


@interface ViewController ()

@property (nonatomic,strong)GPUImageMovie * gpuMovie;//接管视频数据

@property (nonatomic,strong)GPUImageView * gpuView;//预览视频内容

@property (nonatomic,strong)GPUImageOutput<GPUImageInput> * pixellateFilter;//视频滤镜

@property (nonatomic,strong)GPUImageMovieWriter * movieWriter;//视频处理输出

@property (nonatomic,strong)UIScrollView * EditView;//滤镜选择视图

@property (nonatomic,strong)NSArray * GPUImgArr;//存放滤镜数组

@property (nonatomic,copy)NSURL * filePath;//照片库第一个视频路径
@property (nonatomic,copy)NSString * fileSavePath;//视频合成后存储路径

@property (nonatomic,strong)NSMutableDictionary * dic;//存放上个滤镜filter

@property (nonatomic,assign)NSTimer * timer;//设置计时器，因为重复合成同一个滤镜时间会很长超时后重新创建
@property (nonatomic,assign)int timeNum;//记时时间

@property (nonatomic,strong)UIView * hudView;//加载框

@end

@implementation ViewController

- (void)viewDidLoad {
    
    
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _dic = [[NSMutableDictionary alloc]initWithDictionary:@{@"filter":@""}];

    [self getVideoUrl];//获取系统照片库第一个视频文件
    
    
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)getVideoUrl{
    
    NSString *tipTextWhenNoPhotosAuthorization; // 提示语
    // 获取当前应用对照片的访问授权状态
    ALAuthorizationStatus authorizationStatus = [ALAssetsLibrary authorizationStatus];
    // 如果没有获取访问授权，或者访问授权状态已经被明确禁止，则显示提示语，引导用户开启授权
    if (authorizationStatus == ALAuthorizationStatusRestricted || authorizationStatus == ALAuthorizationStatusDenied) {
        NSDictionary *mainInfoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appName = [mainInfoDictionary objectForKey:@"CFBundleDisplayName"];
        tipTextWhenNoPhotosAuthorization = [NSString stringWithFormat:@"请在设备的\"设置-隐私-照片\"选项中，允许%@访问你的手机相册", appName];
        // 展示提示语
    }
    
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (group) {
            
            [group setAssetsFilter:[ALAssetsFilter allVideos]];
            if (group.numberOfAssets > 0) {
                
                [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                    
                    static int i = 1;
                    
                    if (i == 1) {
                        i++;
                        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"]; //注意时间的格式：MM表示月份，mm表示分钟，HH用24小时制，小hh是12小时制。
                        NSString* dateString = [dateFormatter stringFromDate:[result valueForProperty:ALAssetPropertyDate]];
                        
                        if (dateString) {
                            _filePath = result.defaultRepresentation.url;
                            [self createUI];
                        }
                    }
                }];
            }
        }
        
    } failureBlock:^(NSError *error) {
        NSLog(@"Asset group not found!\n");
    }];

    
    
}

-(void)createUI{
    
    _gpuView = [[GPUImageView alloc]initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT-200)];
    //设置展示页面的旋转
//    [_gpuView setInputRotation:kGPUImageRotateRight atIndex:0];
    
    [self.view addSubview:_gpuView];
    
    
    NSLog(@"filePath = %@",_filePath);
    
    _gpuMovie = [[GPUImageMovie alloc]initWithURL:_filePath];
    _gpuMovie.shouldRepeat = YES;//循环

    [_gpuMovie addTarget:_gpuView];

    [_gpuMovie startProcessing];

    [self createEditView];
    
    UIButton * composeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    composeBtn.frame = CGRectMake(30, HEIGHT-80, WIDTH-60, 40);
    
    composeBtn.backgroundColor = [UIColor blackColor];
    
    [composeBtn setTitle:@"合成" forState:UIControlStateNormal];
    
    [composeBtn addTarget:self action:@selector(composeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:composeBtn];
    
}



#pragma mark ---------------------------选择滤镜----------------------------

-(void)effectImgClick:(UIButton *)button{
    
    for (int i = 0 ; i<_GPUImgArr.count ;i++) {
        UIButton *btn = [_EditView viewWithTag:1000+i];
        btn.layer.borderWidth = 0;
        btn.userInteractionEnabled = YES;
    }
    button.userInteractionEnabled = NO;
    button.layer.borderWidth = 2;
    button.layer.borderColor = [UIColor redColor].CGColor;
    
    
    [_gpuMovie cancelProcessing];
    [_gpuMovie removeAllTargets];
    
    _gpuMovie = [[GPUImageMovie alloc]initWithURL:_filePath];

    
    if (button.tag == 1000) {
        _pixellateFilter = nil;
        [_gpuMovie addTarget:_gpuView];
        
    }else{
        _pixellateFilter = (GPUImageOutput<GPUImageInput> *)[_GPUImgArr[button.tag-1000] objectForKey:@"filter"];
        [_gpuMovie addTarget:_pixellateFilter];
        [_pixellateFilter addTarget:_gpuView];
    }
    
    [_gpuMovie startProcessing];
    
}


#pragma mark ----------------------------合成视频点击事件-------------------------
-(void)composeBtnClick:(UIButton *)btn{
    NSLog(@"开始合成");
    if ((_pixellateFilter == nil)|| (_pixellateFilter == _dic[@"filter"] )) {
        NSLog(@"未选择滤镜、或者与上个滤镜重复。请换个滤镜");
        
    }else{
        [self createHudView];
        _timeNum = 0;
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeRun) userInfo:nil repeats:YES];
       
        NSURL *movieURL = [NSURL fileURLWithPath:self.fileSavePath];
        
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(WIDTH, WIDTH*744/720-30)];
        
        [_pixellateFilter addTarget:_movieWriter];
        
        _movieWriter.shouldPassthroughAudio = YES;
        
        [_gpuMovie enableSynchronizedEncodingUsingMovieWriter:_movieWriter];
        [_movieWriter startRecording];
        
        
        __weak ViewController * weakSelf = self;
        
        [_movieWriter setFailureBlock:^(NSError *error) {
            NSLog(@"合成失败 173：error = %@",error.description);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                weakSelf.hudView.hidden = YES;
                
                [weakSelf.pixellateFilter removeTarget:weakSelf.movieWriter];
                [weakSelf.dic setObject:weakSelf.pixellateFilter forKey:@"filter"];
                
                [weakSelf.movieWriter finishRecording];
                
                [weakSelf.timer setFireDate:[NSDate distantFuture]];

            });
        }];
        
        [_movieWriter setCompletionBlock:^{
            NSLog(@"视频合成结束: 188 ");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.hudView.hidden = YES;

                [weakSelf.pixellateFilter removeTarget:weakSelf.movieWriter];
                [weakSelf.dic setObject:weakSelf.pixellateFilter forKey:@"filter"];
                [weakSelf.movieWriter finishRecording];
                
                [weakSelf.timer setFireDate:[NSDate distantFuture]];
                
                
            });
        }];
        
        
    }
    
    
}


#pragma mark -----------------------计时器--------------------------
-(void)timeRun{
    
    _timeNum += 1;
    
    if (_timeNum >= 60) {
        NSLog(@"视频处理超时");
        [_timer invalidate];
        _hudView.hidden = YES;
        [self createUI];
        
    }
    
}




#pragma mark -----------------------------创建加载框------------------------

-(void)createHudView{
    
    if (!_hudView) {
        _hudView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, WIDTH, HEIGHT)];
        _hudView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        
        
        UIView * huV = [[UIView alloc]initWithFrame:CGRectMake(WIDTH/2-50, HEIGHT/2-50, 100, 100)];
        huV.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        
        huV.layer.cornerRadius = 5;
        huV.clipsToBounds = YES;
        
        UIActivityIndicatorView * activityView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        
        
        activityView.frame = CGRectMake(0, 0,huV.frame.size.width, huV.frame.size.height);
        
        [activityView startAnimating];
        
        [huV addSubview:activityView];
        
        [_hudView addSubview:huV];

        
        [WINDOW addSubview:_hudView];
        
    }else{
        
        _hudView.hidden = NO;
        
    }
    
}

#pragma mark -----------------------------视频存放位置------------------------
-(NSString *)fileSavePath{
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSString *pathDocuments = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *createPath = [NSString stringWithFormat:@"%@/myVidio/333.mp4", pathDocuments];//视频存放位置
    NSString *createPath2 = [NSString stringWithFormat:@"%@/myVidio", pathDocuments];//视频存放文件夹
    //判断视频文件是否存在，存在删除
    BOOL blHave=[[NSFileManager defaultManager] fileExistsAtPath:createPath];
    if (blHave) {
        BOOL blDele= [fileManager removeItemAtPath:createPath error:nil];
        if (!blDele) {
            [fileManager removeItemAtPath:createPath error:nil];
        }
    }
    //判断视频存放文件夹是否存在，不存在创建
    BOOL blHave1=[[NSFileManager defaultManager] fileExistsAtPath:createPath2];
    if (!blHave1) {
        [fileManager createDirectoryAtPath:createPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    _fileSavePath = createPath;
    
    
    NSLog(@"视频输出地址 fileSavePath = %@",_fileSavePath);
    
    return _fileSavePath;
}


#pragma mark ---------------------------创建选择滤镜视图----------------------------

-(void)createEditView{
    
    _EditView = [[UIScrollView alloc]initWithFrame:CGRectMake(0, HEIGHT-190, WIDTH, 100)];
    _EditView.showsVerticalScrollIndicator = NO;
    AVURLAsset * myAsset = [AVURLAsset assetWithURL:_filePath];
    
    //初始化AVAssetImageGenerator
    AVAssetImageGenerator * imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    
    UIImage *inputImage = [[UIImage alloc]init];

    // First image
    //创建第一张预览图
    CGImageRef halfWayImage = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:nil error:nil];
    if (halfWayImage != NULL) {
        inputImage = [[UIImage alloc] initWithCGImage:halfWayImage];
    }

    
    _GPUImgArr = [self CreateGPUArr];
    
    for (int i = 0; i<_GPUImgArr.count; i++) {
        
        
        UIButton * effectImg = [UIButton buttonWithType:UIButtonTypeCustom];
        effectImg.frame = CGRectMake(10+i*((WIDTH-10)/5), 10, (WIDTH-10)/5-10,  (WIDTH-10)/5-10);
        [effectImg setImage:inputImage forState:UIControlStateNormal];
        
        if (i>0) {
            
            GPUImageOutput<GPUImageInput> * disFilter = (GPUImageOutput<GPUImageInput> *)[_GPUImgArr[i] objectForKey:@"filter"];
            
            //设置要渲染的区域
            [disFilter useNextFrameForImageCapture];
            //获取数据源
            GPUImagePicture *stillImageSource = [[GPUImagePicture alloc]initWithImage:inputImage];
            //添加上滤镜
            [stillImageSource addTarget:disFilter];
            //开始渲染
            [stillImageSource processImage];
            //获取渲染后的图片
            UIImage *newImage = [disFilter imageFromCurrentFramebuffer];
            
            
            [effectImg setImage:newImage forState:UIControlStateNormal];
            
        }
        
        effectImg.layer.cornerRadius = ((WIDTH-10)/5-10)/2;
        effectImg.layer.masksToBounds = YES;
        effectImg.tag = 1000+i;
        
        [effectImg addTarget:self action:@selector(effectImgClick:) forControlEvents:UIControlEventTouchUpInside];
        
        if (i == 0) {
            effectImg.layer.borderWidth = 2;
            effectImg.layer.borderColor = [UIColor redColor].CGColor;
        }
        
        UILabel * effectName = [[UILabel alloc]initWithFrame:CGRectMake(effectImg.frame.origin.x, CGRectGetMaxY(effectImg.frame)+10, effectImg.frame.size.width, 20)];
        effectName.textColor = [UIColor blackColor];
        effectName.textAlignment = NSTextAlignmentCenter;
        effectName.font = [UIFont systemFontOfSize:12];
        effectName.text = _GPUImgArr[i][@"name"];
        
        [_EditView addSubview:effectImg];
        [_EditView addSubview:effectName];
        
        _EditView.contentSize = CGSizeMake(_GPUImgArr.count*(WIDTH-10)/5+10, _EditView.frame.size.height);
    }
    
    
    [self.view addSubview:_EditView];
}


#pragma mark ------------------------滤镜数组-----------------------

-(NSArray *)CreateGPUArr{
    NSMutableArray * arr = [[NSMutableArray alloc]init];
    
    NSString * title0 = @"原图";
    NSDictionary * dic0 = [NSDictionary dictionaryWithObjectsAndKeys:@"",@"filter",title0,@"name", nil];
    [arr addObject:dic0];
    
    
    GPUImageOutput<GPUImageInput> * Filter5 = [[GPUImageGammaFilter alloc] init];
    [(GPUImageGammaFilter *)Filter5 setGamma:1.5];
    NSString * title5 = @"伽马线";
    NSDictionary * dic5 = [NSDictionary dictionaryWithObjectsAndKeys:Filter5,@"filter",title5,@"name", nil];
    [arr addObject:dic5];
    
    
    GPUImageOutput<GPUImageInput> * Filter6 = [[GPUImageColorInvertFilter alloc] init];
    NSString * title6 = @"反色";
    NSDictionary * dic6 = [NSDictionary dictionaryWithObjectsAndKeys:Filter6,@"filter",title6,@"name", nil];
    [arr addObject:dic6];
    
    GPUImageOutput<GPUImageInput> * Filter7 = [[GPUImageSepiaFilter alloc] init];
    NSString * title7 = @"褐色怀旧";
    NSDictionary * dic7 = [NSDictionary dictionaryWithObjectsAndKeys:Filter7,@"filter",title7,@"name", nil];
    [arr addObject:dic7];
    
    GPUImageOutput<GPUImageInput> * Filter8 = [[GPUImageGrayscaleFilter alloc] init];
    NSString * title8 = @"灰度";
    NSDictionary * dic8 = [NSDictionary dictionaryWithObjectsAndKeys:Filter8,@"filter",title8,@"name", nil];
    [arr addObject:dic8];
    
    GPUImageOutput<GPUImageInput> * Filter9 = [[GPUImageHistogramGenerator alloc] init];
    NSString * title9 = @"色彩直方图？";
    NSDictionary * dic9 = [NSDictionary dictionaryWithObjectsAndKeys:Filter9,@"filter",title9,@"name", nil];
    [arr addObject:dic9];
    
    
    GPUImageOutput<GPUImageInput> * Filter10 = [[GPUImageRGBFilter alloc] init];
    NSString * title10 = @"RGB";
    [(GPUImageRGBFilter *)Filter10 setRed:0.8];
    [(GPUImageRGBFilter *)Filter10 setGreen:0.3];
    [(GPUImageRGBFilter *)Filter10 setBlue:0.5];
    NSDictionary * dic10 = [NSDictionary dictionaryWithObjectsAndKeys:Filter10,@"filter",title10,@"name", nil];
    [arr addObject:dic10];
    
    GPUImageOutput<GPUImageInput> * Filter11 = [[GPUImageMonochromeFilter alloc] init];
    [(GPUImageMonochromeFilter *)Filter11 setColorRed:0.3 green:0.5 blue:0.8];
    NSString * title11 = @"单色";
    NSDictionary * dic11 = [NSDictionary dictionaryWithObjectsAndKeys:Filter11,@"filter",title11,@"name", nil];
    [arr addObject:dic11];
    
    GPUImageOutput<GPUImageInput> * Filter12 = [[GPUImageBoxBlurFilter alloc] init];
    //    [(GPUImageMonochromeFilter *)Filter11 setColorRed:0.3 green:0.5 blue:0.8];
    NSString * title12 = @"单色";
    NSDictionary * dic12 = [NSDictionary dictionaryWithObjectsAndKeys:Filter12,@"filter",title12,@"name", nil];
    [arr addObject:dic12];
    
    GPUImageOutput<GPUImageInput> * Filter13 = [[GPUImageSobelEdgeDetectionFilter alloc] init];
    //    [(GPUImageSobelEdgeDetectionFilter *)Filter13 ];
    NSString * title13 = @"漫画反色";
    NSDictionary * dic13 = [NSDictionary dictionaryWithObjectsAndKeys:Filter13,@"filter",title13,@"name", nil];
    [arr addObject:dic13];
    
    GPUImageOutput<GPUImageInput> * Filter14 = [[GPUImageXYDerivativeFilter alloc] init];
    //    [(GPUImageSobelEdgeDetectionFilter *)Filter13 ];
    NSString * title14 = @"蓝绿边缘";
    NSDictionary * dic14 = [NSDictionary dictionaryWithObjectsAndKeys:Filter14,@"filter",title14,@"name", nil];
    [arr addObject:dic14];
    
    
    GPUImageOutput<GPUImageInput> * Filter15 = [[GPUImageSketchFilter alloc] init];
    //    [(GPUImageSobelEdgeDetectionFilter *)Filter13 ];
    NSString * title15 = @"素描";
    NSDictionary * dic15 = [NSDictionary dictionaryWithObjectsAndKeys:Filter15,@"filter",title15,@"name", nil];
    [arr addObject:dic15];
    
    GPUImageOutput<GPUImageInput> * Filter16 = [[GPUImageSmoothToonFilter alloc] init];
    //    [(GPUImageSobelEdgeDetectionFilter *)Filter13 ];
    NSString * title16 = @"卡通";
    NSDictionary * dic16 = [NSDictionary dictionaryWithObjectsAndKeys:Filter16,@"filter",title16,@"name", nil];
    [arr addObject:dic16];
    
    
    GPUImageOutput<GPUImageInput> * Filter17 = [[GPUImageColorPackingFilter alloc] init];
    //    [(GPUImageSobelEdgeDetectionFilter *)Filter13 ];
    NSString * title17 = @"监控";
    NSDictionary * dic17 = [NSDictionary dictionaryWithObjectsAndKeys:Filter17,@"filter",title17,@"name", nil];
    [arr addObject:dic17];
    
    
    return arr;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
