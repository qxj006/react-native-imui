//
//  DWInputBarControl.m
//  DWInputViewDemo
//
//  Created by Dowin on 2017/7/3.
//  Copyright © 2017年 Dowin. All rights reserved.
//

#import "DWInputBarControl.h"
#import "UIView+Extend.h"
#import "NIMInputEmoticonManager.h"
#import "NIMInputAtCache.h"
#import "DWAudioRecorderManager.h"

@interface DWInputBarControl ()<HPGrowingTextViewDelegate,DWRecordDelegate,NIMInputEmoticonProtocol>{
    UIView *line;
    CGFloat tmpGrowViewH;
}
@property (nonatomic, strong) NIMInputAtCache *atCache;
@property (copy, nonatomic) NSString *strRecordPath;

@end

@implementation DWInputBarControl

- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}


- (void)addNotification{
    //监听键盘变化
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clickKeyBoardChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hidenFeatureView)
                                                 name:@"kHidenFeatureView" object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clickFinishFRecord) name:@"RNNeteaseIMCompleteReocrd" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clickAppWillResignActive) name:@"AppWillResignActive" object:nil];
    //监听选择@人的回调
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(clickGetAtPerson:) name:@"GetAtPersonNotification" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(growingTextViewDeleteBackward) name:@"GrowTextViewDeleteBackWard" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(clickSendRecordMessage) name:@"FinishAudioRecordNotification" object:nil];//录音结束，发送录音message
}

#pragma mark -- 监听键盘
- (void)clickKeyBoardChange:(NSNotification *)noti{
    NSDictionary *userInfo = noti.userInfo;
    NSLog(@"clickKeyBoardChange:%@",userInfo);
    CGRect endFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
//    self.height = screenH - endFrame.origin.y+self.inputViewHeight;
    NSLog(@"----height:%f    ----y:%f",self.height,endFrame.origin.y);
    CGFloat tmpH = screenH - endFrame.origin.y+self.inputViewHeight;
    CGFloat keyboardY = screenH - 20;
    if (!(self.showExpressionBtn.selected || self.showMenuBtn.selected) || (keyboardY > endFrame.origin.y)) {
        NSLog(@"进来了~~~~~");
        if(!self.onShowKeyboard) { return; }
        self.onShowKeyboard(@{@"inputHeight":@(tmpH),@"showType":@(0)});
    }
//    [[NSNotificationCenter defaultCenter]postNotificationName:@"ChangeMessageListHeightNotification" object:@{@"listViewHeight":@(screenH - 60 - tmpH)}];
    

}

- (void)hidenFeatureView{
    __weak typeof(self)weakSelf = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        [weakSelf.inputGrowView endEditing:YES];
        [UIView animateWithDuration:1.0 animations:^{
            if (weakSelf.showMenuBtn.selected && (weakSelf.height > self.menuViewH )) {
                weakSelf.showMenuBtn.selected = NO;
                weakSelf.height = weakSelf.height - self.menuViewH;
                weakSelf.onFeatureView(@{@"inputHeight":@(weakSelf.height),@"showType":@(0)});
            }else if(weakSelf.showExpressionBtn.selected && (weakSelf.height > expressionViewH )){
                weakSelf.showExpressionBtn.selected = NO;
                weakSelf.height = weakSelf.height - expressionViewH;
                weakSelf.onFeatureView(@{@"inputHeight":@(weakSelf.height),@"showType":@(0)});
            }
        } completion:^(BOOL finished) {
            weakSelf.expressionView.hidden = YES;
        }];

    });
    
}
//监听删除按键
- (void)growingTextViewDeleteBackward{
    [self onTextDelete];
}

//
- (void)clickAppWillResignActive{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recordBtn setButtonStateWithNormal];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Complete"];
    });
}

- (void)clickGetAtPerson:(NSNotification *)notifi{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *person = notifi.object;
        NIMInputAtItem *item = [[NIMInputAtItem alloc] init];
        NSString *strName = [NSString stringWithFormat:@"%@%@",[person objectForKey:@"name"],NIMInputAtEndChar];
        item.uid = [person objectForKey:@"userId"];
        item.name = [person objectForKey:@"name"];
        [self.atCache addAtItem:item];
        NSRange range = self.inputGrowView.selectedRange;
        NSString *replaceText = [self.inputGrowView.text stringByReplacingCharactersInRange:range withString:strName];
        range = NSMakeRange(range.location + strName.length, 0);
        self.inputGrowView.text = replaceText;
        self.inputGrowView.selectedRange = range;
        [self.inputGrowView becomeFirstResponder];
    });
}


- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        _atCache = [[NIMInputAtCache alloc] init];
        [self addSubContentView];
    }
    [self addNotification];
    return self;
}


- (void)setDefaultToolHeight:(CGFloat)defaultToolHeight{
    if (defaultToolHeight) {
        _defaultToolHeight = defaultToolHeight;
    }else{
        _defaultToolHeight = DESIGN_SIZE_750(90);
    }
    _toolH = _defaultToolHeight;
    _inputViewHeight = _defaultToolHeight;
    [self creatUI];
}
//发送录音message
- (void)clickSendRecordMessage{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recordBtn setButtonStateWithNormal];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Complete"];
        if (self.onSendRecordMessage) {
            self.onSendRecordMessage(@{@"Path":self.strRecordPath});
        }
    });
    NSLog(@"strRecordPath:%@",self.strRecordPath);
}


- (void)addSubContentView{
    _toolView = [[UIView alloc]init];
    _toolView.backgroundColor = [UIColor whiteColor];
    [self addSubview:_toolView];
    
    line = [[UIView alloc]init];
    line.backgroundColor = [UIColor colorWithRed:235/255.0 green:235/255.0 blue:235/255.0 alpha:1.0];
    [_toolView addSubview:line];
    
    _showRecordeBtn = [[UIButton alloc]init];
    _showRecordeBtn.tag = DWInputBarControlBtnTypeRecord;
    [_showRecordeBtn addTarget:self action:@selector(clickControlBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_toolView addSubview:_showRecordeBtn];
    
    _inputGrowView = [[HPGrowingTextView alloc]init];
    _inputGrowView.backgroundColor = [UIColor whiteColor];
    _inputGrowView.layer.cornerRadius = 5.0f;
    _inputGrowView.layer.borderColor = [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1.0].CGColor;
    _inputGrowView.layer.borderWidth = 1;
//    _inputGrowView.contentInset = UIEdgeInsetsMake(5, 5, 5, 5);
    _inputGrowView.returnKeyType = UIReturnKeySend;
    _inputGrowView.enablesReturnKeyAutomatically = YES;
    _inputGrowView.font = [UIFont systemFontOfSize:15.0f];
    _inputGrowView.delegate = self;
//    _inputGrowView.placeholder = @"点击输入文字";
    _inputGrowView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_toolView addSubview:_inputGrowView];
    
    _recordBtn = [[DWRecordButton alloc]init];
    _recordBtn.textArr = @[@"按住 说话",@"松开 结束",@"松开 取消"];
    _recordBtn.hidden = YES;
    _recordBtn.delegate = self;
    [_toolView addSubview:_recordBtn];
    
    _showExpressionBtn = [[UIButton alloc]init];
    _showExpressionBtn.tag = DWInputBarControlBtnTypeExpression;
    [_showExpressionBtn addTarget:self action:@selector(clickControlBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_toolView addSubview:_showExpressionBtn];
    _showMenuBtn = [[UIButton alloc]init];
    _showMenuBtn.tag = DWInputBarControlBtnTypeMenu;
    [_showMenuBtn addTarget:self action:@selector(clickControlBtn:) forControlEvents:UIControlEventTouchUpInside];
    [_toolView addSubview:_showMenuBtn];
    
    _expressionView = [[NIMInputEmoticonContainerView alloc]initWithFrame:CGRectMake(0, 0, screenW, expressionViewH)];
//    _expressionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _expressionView.delegate = self;
    [self addSubview:_expressionView];
    _expressionView.hidden = YES;

    [_showMenuBtn setBackgroundImage:[UIImage imageNamed:@"more_ios"] forState:UIControlStateNormal];
    [_showMenuBtn setBackgroundImage:[UIImage imageNamed:@"more_ios_HL"] forState:UIControlStateHighlighted];
    [_showExpressionBtn setBackgroundImage:[UIImage imageNamed:@"face"] forState:UIControlStateNormal];
    [_showExpressionBtn setBackgroundImage:[UIImage imageNamed:@"face_HL"] forState:UIControlStateHighlighted];
    [_showExpressionBtn setBackgroundImage:[UIImage imageNamed:@"keyboard"] forState:UIControlStateSelected];
    [_showRecordeBtn setBackgroundImage:[UIImage imageNamed:@"voice"] forState:UIControlStateNormal];
    [_showRecordeBtn setBackgroundImage:[UIImage imageNamed:@"voice_HL"] forState:UIControlStateHighlighted];
    [_showRecordeBtn setBackgroundImage:[UIImage imageNamed:@"keyboard"] forState:UIControlStateSelected];
    
}

- (void)setToolH:(CGFloat)toolH{
    if (toolH) {
        _toolH = toolH;
        [self creatUI];
    }
}

- (void)creatUI{
    line.frame = CGRectMake(0, 0, screenW, 1);
    CGFloat _margin = _defaultToolHeight*0.1;
    CGFloat btnWH = _defaultToolHeight - 3*_margin;
    _toolView.frame = CGRectMake(0, 0, screenW, _toolH);

    CGFloat btnY = _toolH - 1.5*_margin - btnWH;
    _showRecordeBtn.frame = CGRectMake(_margin,btnY, btnWH, btnWH);
    
    CGFloat menuBtnX = screenW - _margin - btnWH;
    _showMenuBtn.frame = CGRectMake(menuBtnX, btnY, btnWH, btnWH);
    
    CGFloat expressionBtnX = menuBtnX - 1.5*_margin - btnWH;
    _showExpressionBtn.frame = CGRectMake(expressionBtnX, btnY, btnWH, btnWH);
    
    CGFloat inputX = CGRectGetMaxX(_showRecordeBtn.frame)+1.5*_margin;
    CGFloat inputW = expressionBtnX - inputX - 1.5*_margin;
    CGFloat inputY = _margin;
    CGFloat inputH = _toolH - 2*_margin;
    _inputGrowView.frame = CGRectMake(inputX, inputY+DESIGN_SIZE_750(5), inputW, inputH);
    _recordBtn.frame = CGRectMake(inputX, inputY+DESIGN_SIZE_750(2.5), inputW, inputH-DESIGN_SIZE_750(8));

    _expressionView.y = CGRectGetMaxY(_toolView.frame);
}


- (void)layoutSubviews{
    _inputGrowView.minNumberOfLines = 0.5;
    _inputGrowView.maxNumberOfLines = 4;
    
}

//点击按钮
- (void)clickControlBtn:(UIButton *)btn{
    if ([self.delegate respondsToSelector:@selector(inputBarClickBtn:)]) {
        [self.delegate inputBarClickBtn:btn];
    }
}

//获取保存录音路径
- (NSString *)getSaveRecordPath{
    NSString *dirPath = NSTemporaryDirectory();
    NSTimeInterval interval = [[NSDate date] timeIntervalSince1970];
    NSString *recordName = [NSString stringWithFormat:@"%.0f.aac",interval];
    NSString *soundFilePath = [dirPath stringByAppendingPathComponent:recordName];
    return soundFilePath;
}

#pragma mark DWRecordButton录音按钮代理方法
- (void)recordTouchDownAction:(DWRecordButton *)btn{
    NSLog(@"开始录音");
    if (!btn.selected) {
        btn.selected = YES;
        [btn setButtonStateWithRecording];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Start"];
        _strRecordPath = [self getSaveRecordPath];
        [[DWAudioRecorderManager shareManager] audioRecorderStartWithFilePath:_strRecordPath ];

    }
}
- (void)recordTouchUpOutsideAction:(DWRecordButton *)btn{
    NSLog(@"取消录音");
    [btn setButtonStateWithNormal];
    [[DWAudioRecorderManager shareManager] audioRecorderCancel];
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Canceled"];
}
- (void)recordTouchUpInsideAction:(DWRecordButton *)btn{
    NSLog(@"完成录音");
    [btn setButtonStateWithNormal];
    [[DWAudioRecorderManager shareManager] audioRecorderStop];
}

- (void)recordTouchDragInsideAction:(DWRecordButton *)btn{
    //持续调用

}
- (void)recordTouchDragOutsideAction:(DWRecordButton *)btn{
    //持续调用

}
//中间状态  从 TouchDragOutside ---> TouchDragInside
- (void)recordTouchDragEnterAction:(DWRecordButton *)btn{
    if (btn.selected) {
        NSLog(@"继续录音");
        [btn setButtonStateWithRecording];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Continue"];
    }
}
//中间状态  从 TouchDragInside ---> TouchDragOutside
- (void)recordTouchDragExitAction:(DWRecordButton *)btn{
    if (btn.selected) {
        NSLog(@"将要取消录音");
        [btn setButtonStateWithCancel];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"RecordChangeNotification" object:@"Move"];
    }
}

#pragma mark - HPGrowingTextViewDelegate
- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height {
    __weak __typeof(self)weakSelf = self;
    float diff = (growingTextView.frame.size.height - height);
    void(^animations)() = ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            CGRect rect = self.frame;
            rect.size.height -= diff;
            self.frame = rect;
            
            self.toolH -= diff;
            self.inputViewHeight -= diff;
            if(!self.onChangeBarHeight) { return; }
            self.onChangeBarHeight(@{@"inputHeight":@(self.height),@"marginTop":@(self.toolH)});
        }
    };
    [UIView animateWithDuration:0.1 delay:0.0f options:(UIViewAnimationOptionBeginFromCurrentState) animations:animations completion:nil];
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView didChangeHeight:(float)height{
    tmpGrowViewH = growingTextView.frame.size.height;
}

- (BOOL)growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    if ([text isEqualToString:@"@"]) {
        self.onClickMention(@{});
    }
    if ([text isEqualToString:@"\n"]){ //判断输入的字是否是回车，即按下return
        //在这里做你响应return键的代码
        
        NSArray *uuidArr = [self.atCache allAtUid:growingTextView.text];
        self.onSendTextMessage(@{@"text":growingTextView.text,@"IDArr":uuidArr});
        growingTextView.text = @"";
        
        return NO; //这里返回NO，就代表return键值失效，即页面上按下return，不会出现换行，如果为yes，则输入页面会换行
    }
    return YES;
}

- (void)growingTextViewDidBeginEditing:(HPGrowingTextView *)growingTextView{
    if (!tmpGrowViewH) {
        tmpGrowViewH = growingTextView.size.height;
    }else{
        growingTextView.height = tmpGrowViewH;
    }
    self.expressionView.hidden = YES;
    self.showExpressionBtn.selected = NO;
    self.showMenuBtn.selected = NO;
}


#pragma mark - InputEmoticonProtocol
- (void)selectedEmoticon:(NSString*)emoticonID catalog:(NSString*)emotCatalogID description:(NSString *)description{
    if (!emotCatalogID) { //删除键
        [self onTextDelete];
    }else{
        if ([emotCatalogID isEqualToString:@"default"]) {
            self.inputGrowView.text = [NSString stringWithFormat:@"%@%@",_inputGrowView.text,description];
        }else{
            //发送贴图消息

        }
    }
}

- (void)didPressSend:(id)sender{
    NSArray *uuidArr = [self.atCache allAtUid:self.inputGrowView.text];
    self.onSendTextMessage(@{@"text":self.inputGrowView.text,@"IDArr":uuidArr});
    self.inputGrowView.text = @"";
}

//删除Text
- (void)onTextDelete
{
    NSRange range = [self delRangeForEmoticon];
    if (range.length == 1) {
        //删的不是表情，可能是@
        NIMInputAtItem *item = [self delRangeForAt];
        if (item) {
            range = item.range;
        }
    }
    [self deleteText:range];
}

- (NSRange)delRangeForEmoticon
{
    NSString *text = self.inputGrowView.text;
    NSRange range = [self rangeForPrefix:@"[" suffix:@"]"];
    NSRange selectedRange = [self.inputGrowView selectedRange];
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        NIMInputEmoticon *icon = [[NIMInputEmoticonManager sharedManager] emoticonByTag:name];
        range = icon? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    return range;
}

- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSString *text = self.inputGrowView.text;
    NSRange range = [self.inputGrowView selectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

- (void)deleteText:(NSRange)range
{
    NSString *text = self.inputGrowView.text;
    if (range.location + range.length <= [text length]
        && range.location != NSNotFound && range.length != 0)
    {
        NSString *newText = [text stringByReplacingCharactersInRange:range withString:@""];
        NSRange newSelectRange = NSMakeRange(range.location, 0);
        [self.inputGrowView setText:newText];
        self.inputGrowView.selectedRange = newSelectRange;
    }
}
//删除@的人
- (NIMInputAtItem *)delRangeForAt
{
    NSString *text = self.inputGrowView.text;
    NSRange range = [self rangeForPrefix:NIMInputAtStartChar suffix:NIMInputAtEndChar];
    NSRange selectedRange = [self.inputGrowView selectedRange];
    NIMInputAtItem *item = nil;
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        NSString *set = [NIMInputAtStartChar stringByAppendingString:NIMInputAtEndChar];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:set]];
        item = [self.atCache item:name];
        range = item? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    item.range = range;
    return item;
}

@end
